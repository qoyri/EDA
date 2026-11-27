defmodule EDA.Test.DaveGateway do
  @moduledoc false

  # A voice gateway for DAVE tests.
  #
  # It does what Discord's does for a call: hands every member the external sender, proposes who
  # joins and who leaves, relays the commit one member answers with to the others and its welcome
  # to those being added, and announces when a transition executes. The members are real
  # `EDA.Voice.Dave.Manager`s over real MLS sessions, and every message reaches them through
  # `handle_mls_event/3` in the shape `EDA.Voice.Session` decodes it to, so a test follows a call
  # the way a bot lives it, without Discord.
  #
  # Each step is its own function, so a test can stop between a transition being announced and
  # executed, which is where the protocol is delicate.

  alias EDA.Test.DaveGateway.Native
  alias EDA.Voice.Dave.Manager

  defstruct [
    :ref,
    :channel_id,
    # The epoch of the group, as the gateway counts it: 0 until a group exists.
    epoch: 0,
    # user id => manager, for everyone connected to the call.
    members: %{},
    # user id => leaf, for those in the group.
    leaves: %{},
    # user id => the last key package the member sent.
    key_packages: %{},
    # What members sent back, newest first: {user_id, {:ready, transition_id}},
    # {user_id, {:invalid, transition_id}}, {user_id, :key_package}, {user_id, :commit}.
    sent: []
  ]

  @doc "A gateway for a call in a channel of its own."
  def new do
    channel_id = System.unique_integer([:positive]) + 1_000_000_000_000
    {:ok, ref} = Native.new(channel_id)
    %__MODULE__{ref: ref, channel_id: channel_id}
  end

  @doc """
  Connects a user: the session is created for the negotiated protocol version, receives the
  external sender and offers its key package, as after SESSION_DESCRIPTION.
  """
  def connect(%__MODULE__{} = gateway, user_id) do
    manager = Manager.new(1, user_id, gateway.channel_id)
    {:ok, external_sender} = Native.external_sender(gateway.ref)

    gateway = %{gateway | members: Map.put(gateway.members, user_id, manager)}
    {gateway, []} = deliver(gateway, user_id, 25, %{"external_sender_bin" => external_sender})

    {:ok, payload} = Manager.key_package_payload(member(gateway, user_id))
    record(gateway, user_id, [payload])
  end

  @doc "The manager of a connected user."
  def member(%__MODULE__{members: members}, user_id), do: Map.fetch!(members, user_id)

  @doc "What a member sent to the gateway, oldest first."
  def sent(%__MODULE__{sent: sent}, user_id) do
    for {^user_id, message} <- Enum.reverse(sent), do: message
  end

  @doc """
  Delivers one opcode to one member and records what it answers. Proposals and welcomes carry the
  clients the session knows to be connected, everyone else in the call unless `:connected_clients`
  says otherwise.
  """
  def deliver(%__MODULE__{} = gateway, user_id, op, data, opts \\ []) do
    data =
      if op in [27, 30] do
        clients = Keyword.get_lazy(opts, :connected_clients, fn -> others(gateway, user_id) end)
        Map.put(data, "connected_clients", MapSet.new(clients, &to_string/1))
      else
        data
      end

    {manager, replies} = Manager.handle_mls_event(member(gateway, user_id), op, data)
    gateway = %{gateway | members: Map.put(gateway.members, user_id, manager)}
    {record(gateway, user_id, replies), replies}
  end

  @doc """
  Sends proposals to `to`: to add the users in `:add`, with the last key package each sent, and to
  remove those in `:remove`. Returns what each of `to` answered: `{commit, welcome}`, `welcome`
  being nil for a commit that adds no one, or nil for a member that did not commit.
  """
  def propose(%__MODULE__{} = gateway, to, changes) do
    key_packages =
      for id <- Keyword.get(changes, :add, []), do: Map.fetch!(gateway.key_packages, id)

    leaves = for id <- Keyword.get(changes, :remove, []), do: Map.fetch!(gateway.leaves, id)
    {:ok, proposals} = Native.proposals(gateway.ref, gateway.epoch, key_packages, leaves)

    Enum.reduce(to, {gateway, %{}}, fn user_id, {gateway, answers} ->
      data = %{"operation_type" => 0, "proposals_bin" => proposals}
      {gateway, replies} = deliver(gateway, user_id, 27, data)
      {gateway, Map.put(answers, user_id, commit_welcome(replies))}
    end)
  end

  @doc """
  Announces a commit as transition `transition_id`: the commit to the members already in the
  group, the welcome to the users in `:add`. The group is then one epoch further, without those in
  `:remove`.
  """
  def announce(%__MODULE__{} = gateway, transition_id, {commit, welcome}, changes \\ []) do
    added = Keyword.get(changes, :add, [])
    removed = Keyword.get(changes, :remove, [])
    in_group = Keyword.get_lazy(changes, :to, fn -> Map.keys(gateway.leaves) end)

    gateway =
      Enum.reduce(in_group, gateway, fn user_id, gateway ->
        data = %{"transition_id" => transition_id, "commit_bin" => commit}
        elem(deliver(gateway, user_id, 29, data), 0)
      end)

    gateway =
      Enum.reduce(added, gateway, fn user_id, gateway ->
        data = %{"transition_id" => transition_id, "welcome_bin" => welcome}
        elem(deliver(gateway, user_id, 30, data), 0)
      end)

    %{gateway | epoch: gateway.epoch + 1, leaves: seat(gateway.leaves, added, removed)}
  end

  @doc "Executes a transition for everyone in the group."
  def execute(%__MODULE__{} = gateway, transition_id) do
    Enum.reduce(Map.keys(gateway.leaves), gateway, fn user_id, gateway ->
      elem(deliver(gateway, user_id, 22, %{"transition_id" => transition_id}), 0)
    end)
  end

  @doc """
  A whole change of membership: proposals to the group, the commit of `:committer` (the first
  member to answer otherwise) announced as `:transition`, and its execution unless that is 0, which
  needs none.

  Without a group yet, `:committer` is the member that creates it.
  """
  def change(%__MODULE__{} = gateway, opts) do
    added = Keyword.get(opts, :add, [])
    removed = Keyword.get(opts, :remove, [])
    transition_id = Keyword.get(opts, :transition, 0)

    committers =
      case Map.keys(gateway.leaves) -- removed do
        [] -> [Keyword.fetch!(opts, :committer)]
        members -> members
      end

    {gateway, answers} = propose(gateway, committers, add: added, remove: removed)
    winner = Keyword.get(opts, :committer, hd(committers))
    gateway = seat_creator(gateway, winner)

    gateway =
      announce(gateway, transition_id, Map.fetch!(answers, winner), add: added, remove: removed)

    if transition_id == 0, do: gateway, else: execute(gateway, transition_id)
  end

  @doc "Gives the creator of a group its seat: the member that commits from a pending group."
  def seat_creator(%__MODULE__{leaves: leaves} = gateway, user_id) when leaves == %{},
    do: %{gateway | leaves: %{user_id => 0}}

  def seat_creator(%__MODULE__{} = gateway, _user_id), do: gateway

  @doc "Encrypts a frame as `user_id` would send it."
  def encrypt(%__MODULE__{} = gateway, user_id, frame) do
    case Manager.encrypt_frame(member(gateway, user_id), frame) do
      {:ok, encrypted, _manager} -> {:ok, encrypted}
      {:error, reason, _manager} -> {:error, reason}
    end
  end

  @doc "Decrypts, as `user_id`, a frame received from `sender_id`."
  def decrypt(%__MODULE__{} = gateway, user_id, sender_id, frame) do
    case Manager.decrypt_frame(member(gateway, user_id), frame, sender_id) do
      {:ok, decrypted, _manager} -> {:ok, decrypted}
      {:error, reason} -> {:error, reason}
    end
  end

  defp others(gateway, user_id), do: Map.keys(gateway.members) -- [user_id]

  # A removed member's leaf is free again, and a new member takes the leftmost free one.
  defp seat(leaves, added, removed) do
    leaves = Map.drop(leaves, removed)

    Enum.reduce(added, leaves, fn user_id, leaves ->
      taken = Map.values(leaves)
      leaf = Enum.find(Stream.iterate(0, &(&1 + 1)), &(&1 not in taken))
      Map.put(leaves, user_id, leaf)
    end)
  end

  defp commit_welcome(replies) do
    Enum.find_value(replies, fn
      {:binary, <<28, payload::binary>>} ->
        {:ok, {commit, welcome}} = Native.split_commit_welcome(payload)
        {commit, welcome}

      _ ->
        nil
    end)
  end

  defp record(gateway, user_id, replies) do
    Enum.reduce(replies, gateway, fn reply, gateway ->
      case reply do
        {:binary, <<26, key_package::binary>>} ->
          gateway = %{gateway | key_packages: Map.put(gateway.key_packages, user_id, key_package)}
          note(gateway, user_id, :key_package)

        {:binary, <<28, _::binary>>} ->
          note(gateway, user_id, :commit)

        %{op: 23, d: %{transition_id: id}} ->
          note(gateway, user_id, {:ready, id})

        %{op: 31, d: %{transition_id: id}} ->
          note(gateway, user_id, {:invalid, id})
      end
    end)
  end

  defp note(gateway, user_id, message), do: %{gateway | sent: [{user_id, message} | gateway.sent]}
end
