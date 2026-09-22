defmodule EDA.Voice.Dave.Manager do
  @moduledoc """
  Coordinates the DAVE (Discord Audio Video E2EE) protocol.

  This is a pure struct (not a GenServer) to avoid bottlenecks on the
  audio hot path (50 frames/sec). The NIF resource is thread-safe
  (Mutex on the Rust side).

  When `protocol_version` is 0, all operations are passthrough (zero-cost).
  """

  require Logger

  alias EDA.Voice.Dave.Native
  alias EDA.Voice.Payload

  # Final catch-alls at the NIF boundary. The specs in EDA.Voice.Dave.Native now
  # enumerate every shape Rustler actually produces, so Dialyzer sees these as
  # unreachable — they are kept deliberately: an unexpected NIF return must degrade
  # to passthrough on the 50 fps audio path, not crash the voice session.
  @dialyzer {:nowarn_function,
             encrypt_frame: 2, encrypt_with_session: 3, normalize_encrypt_result: 1}

  # Seconds decryptors keep accepting unencrypted frames after an upgrade, and while a downgrade to
  # protocol 0 is pending. Transitions take about three seconds; the downgrade window also covers
  # delayed connections.
  @transition_expiry 10
  @pending_downgrade_expiry 24

  # Frames that may fail to decrypt in a row before the session is re-initialised, as in Discord's
  # reference client. Failures while re-initialising or during a transition are expected, and not
  # counted.
  @decrypt_failure_tolerance 36

  # Discord sends Opus silence frames unencrypted.
  @silence <<0xF8, 0xFF, 0xFE>>

  defstruct [
    :mls_session,
    :protocol_version,
    :user_id,
    :channel_id,
    :version_ref,
    :last_transition_id,
    pending_transitions: %{},
    downgraded: false,
    reinitializing: false,
    transitions: 0,
    decrypt_failures: 0
  ]

  @typedoc """
  The DAVE state of one voice connection.

  `protocol_version` is the version in effect. The playback process works on a copy of this struct
  taken when the connection became ready, so the version is also held in `version_ref`, an
  `:atomics` shared by every copy: a transition executed by the session reaches playback already
  under way. `transitions` counts executed transitions, `decrypt_failures` the frames that failed
  to decrypt in a row.
  """
  @type t :: %__MODULE__{
          mls_session: reference() | nil,
          protocol_version: non_neg_integer(),
          user_id: non_neg_integer(),
          channel_id: non_neg_integer(),
          version_ref: :atomics.atomics_ref() | nil,
          last_transition_id: non_neg_integer() | nil,
          pending_transitions: %{non_neg_integer() => non_neg_integer()},
          downgraded: boolean(),
          reinitializing: boolean(),
          transitions: non_neg_integer(),
          decrypt_failures: non_neg_integer()
        }

  @doc "Creates a new DAVE manager. Version 0 means passthrough (no E2EE)."
  @spec new(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def new(protocol_version, user_id, channel_id) do
    session =
      if protocol_version > 0 do
        case safe_new_session(protocol_version, user_id, channel_id) do
          {:ok, ref} when is_reference(ref) ->
            ref

          ref when is_reference(ref) ->
            ref

          _ ->
            Logger.warning("DAVE: Failed to create MLS session, falling back to passthrough")
            nil
        end
      else
        nil
      end

    version_ref = :atomics.new(1, signed: false)
    :atomics.put(version_ref, 1, protocol_version)

    %__MODULE__{
      mls_session: session,
      protocol_version: protocol_version,
      user_id: user_id,
      channel_id: channel_id,
      version_ref: version_ref
    }
  end

  @doc """
  The protocol version currently in effect, including transitions executed after this copy of the
  manager was taken.
  """
  @spec current_version(t()) :: non_neg_integer()
  def current_version(%__MODULE__{version_ref: nil, protocol_version: v}), do: v
  def current_version(%__MODULE__{version_ref: ref}), do: :atomics.get(ref, 1)

  @doc "Returns true if DAVE E2EE is active (version > 0 and NIF session available)."
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{protocol_version: v, mls_session: s}), do: v > 0 and not is_nil(s)

  @doc "Returns true when the MLS session is ready to encrypt media."
  @spec ready?(t()) :: boolean()
  def ready?(%__MODULE__{mls_session: nil}), do: false

  def ready?(%__MODULE__{mls_session: session}) do
    case normalize_ready_result(Native.ready?(session)) do
      {:ok, ready} -> ready
      _ -> false
    end
  end

  @doc """
  Encrypts an Opus frame through DAVE E2EE.

  In passthrough mode, returns the frame unchanged.
  Returns `{:ok, encrypted_frame, updated_manager}` on success.
  Returns `{:error, reason, updated_manager}` when an active DAVE session
  cannot encrypt media, so callers can stop playback instead of sending
  undecryptable raw Opus.
  """
  @spec encrypt_frame(t(), binary()) :: {:ok, binary(), t()} | {:error, term(), t()}
  def encrypt_frame(%__MODULE__{protocol_version: 0, mls_session: nil} = manager, opus_frame) do
    {:ok, opus_frame, manager}
  end

  def encrypt_frame(%__MODULE__{mls_session: nil} = manager, _opus_frame) do
    {:error, :session_unavailable, manager}
  end

  def encrypt_frame(%__MODULE__{mls_session: session} = manager, opus_frame) do
    if current_version(manager) == 0 do
      # The call was downgraded to protocol 0: Discord now expects unencrypted media.
      {:ok, opus_frame, manager}
    else
      encrypt_with_session(manager, session, opus_frame)
    end
  end

  defp encrypt_with_session(manager, session, opus_frame) do
    case normalize_encrypt_result(Native.encrypt_opus(session, opus_frame)) do
      {:ok, encrypted} ->
        {:ok, encrypted, manager}

      {:error, :not_ready} ->
        Logger.warning("DAVE: encrypt_opus not ready, aborting media send")
        {:error, :not_ready, manager}

      # normalize_encrypt_result/1 already turns any other shape into {:error, _}, so this
      # clause is the last one that can match.
      {:error, reason} ->
        Logger.warning("DAVE: encrypt_opus failed (#{inspect(reason)}), aborting media send")
        {:error, reason, manager}
    end
  end

  @doc """
  Decrypts a DAVE-encrypted frame.

  In passthrough mode, returns the frame unchanged.
  Returns `{:ok, decrypted_frame, updated_manager}` or `{:error, reason}`. On an error, pass the
  manager to `decrypt_failed/1`.
  """
  @spec decrypt_frame(t(), binary(), non_neg_integer()) ::
          {:ok, binary(), t()} | {:error, atom()}
  def decrypt_frame(%__MODULE__{mls_session: nil} = manager, frame, _sender_user_id) do
    {:ok, frame, manager}
  end

  def decrypt_frame(%__MODULE__{} = manager, @silence, _sender_user_id) do
    {:ok, @silence, decrypted(manager)}
  end

  def decrypt_frame(%__MODULE__{mls_session: session} = manager, frame, sender_user_id) do
    if current_version(manager) == 0 do
      {:ok, frame, decrypted(manager)}
    else
      decrypt_with_session(manager, session, frame, sender_user_id)
    end
  end

  defp decrypt_with_session(manager, session, frame, sender_user_id) do
    case normalize_decrypt_result(Native.decrypt_audio(session, sender_user_id, frame)) do
      {:ok, decrypted} ->
        {:ok, decrypted, decrypted(manager)}

      _ ->
        if passthrough?(session, sender_user_id) do
          {:ok, frame, decrypted(manager)}
        else
          :telemetry.execute([:eda, :voice, :dave, :frame_decrypt_error], %{count: 1}, %{
            user_id: sender_user_id
          })

          {:error, :decrypt_failed}
        end
    end
  end

  # The NIF answers `{:ok, boolean}`: the tuple itself is truthy, so testing it directly let every
  # frame that failed to decrypt through as if passthrough were allowed.
  defp passthrough?(session, user_id) do
    case Native.can_passthrough?(session, user_id) do
      {:ok, true} -> true
      true -> true
      _ -> false
    end
  end

  # A frame got through: a run of failures, if any, is over. Leaves the struct untouched otherwise, as
  # this runs for every frame received.
  defp decrypted(%__MODULE__{decrypt_failures: 0} = manager), do: manager
  defp decrypted(manager), do: %{manager | decrypt_failures: 0}

  @doc """
  Records a frame that failed to decrypt, and recovers once too many fail in a row.

  A session that stops decrypting — the group state out of step with the other members — would
  otherwise stay broken until the bot leaves the channel. After #{@decrypt_failure_tolerance}
  failures in a row, the last transition is reported as invalid (OP 31) and the session is
  re-initialised with a fresh key package, so Discord removes the bot from the group and adds it
  again. Failures while that is under way, or while a transition is pending, are expected and not
  counted.

  Returns the updated manager and the payloads to send to the voice gateway.
  """
  @spec decrypt_failed(t()) :: {t(), [term()]}
  def decrypt_failed(%__MODULE__{reinitializing: true} = manager), do: {manager, []}

  def decrypt_failed(%__MODULE__{pending_transitions: pending} = manager)
      when map_size(pending) > 0,
      do: {manager, []}

  def decrypt_failed(%__MODULE__{decrypt_failures: failures} = manager)
      when failures < @decrypt_failure_tolerance,
      do: {%{manager | decrypt_failures: failures + 1}, []}

  def decrypt_failed(%__MODULE__{last_transition_id: nil, decrypt_failures: failures} = manager) do
    # Nothing to report yet: the session has not joined a group. Said once, not per frame.
    if failures == @decrypt_failure_tolerance do
      Logger.warning(
        "DAVE: #{failures + 1} frames in a row failed to decrypt before the session joined a group"
      )
    end

    {%{manager | decrypt_failures: failures + 1}, []}
  end

  def decrypt_failed(%__MODULE__{last_transition_id: transition_id} = manager) do
    Logger.warning(
      "DAVE: #{manager.decrypt_failures + 1} frames in a row failed to decrypt, " <>
        "re-initialising the session (transition #{transition_id})"
    )

    recover_from_invalid_transition(%{manager | decrypt_failures: 0}, transition_id)
  end

  @doc """
  Builds an OP26 key package payload from the current MLS session.

  Returns `{:ok, payload}` when available, otherwise `:error`.
  """
  @spec key_package_payload(t()) :: {:ok, term()} | :error
  def key_package_payload(%__MODULE__{mls_session: nil}), do: :error

  def key_package_payload(%__MODULE__{mls_session: session}) do
    case normalize_key_package_result(Native.create_key_package(session)) do
      {:ok, key_package} ->
        {:ok, Payload.dave_mls_key_package(key_package)}

      _ ->
        :error
    end
  end

  @doc """
  Handles an MLS-related voice gateway event.

  Returns `{updated_manager, reply_payloads}` where `reply_payloads` is
  a list of payloads to send back to the voice gateway.
  """
  @spec handle_mls_event(t(), non_neg_integer(), map()) :: {t(), list()}

  # OP 25: DAVE_MLS_EXTERNAL_SENDER
  #
  # The key package already went out after SESSION_DESCRIPTION; sending another here would only give
  # the gateway a second, redundant one.
  def handle_mls_event(%__MODULE__{mls_session: session} = manager, 25, data)
      when not is_nil(session) do
    with {:ok, credential} <- raw_or_base64(data, "external_sender_bin", "external_sender"),
         :ok <- Native.set_external_sender(session, credential) do
      Logger.debug("DAVE: External sender set")
      {manager, []}
    else
      {:error, reason} ->
        Logger.error("DAVE: Missing/invalid external sender payload (#{inspect(reason)})")
        {manager, []}

      :error ->
        Logger.error("DAVE: Failed to set external sender")
        {manager, []}
    end
  end

  # OP 27: DAVE_MLS_PROPOSALS
  def handle_mls_event(%__MODULE__{mls_session: session} = manager, 27, data)
      when not is_nil(session) do
    op_type = proposal_operation_type(data["operation_type"])
    user_ids = connected_clients_to_ids(data["connected_clients"])

    with {:ok, proposals} <- raw_or_base64(data, "proposals_bin", "proposals"),
         {:process_proposals, {:ok, commit, welcome}} <-
           {:process_proposals,
            normalize_process_proposals_result(
              Native.process_proposals(session, op_type, proposals, user_ids)
            )} do
      proposals_reply(manager, commit, welcome)
    else
      {:error, reason} ->
        Logger.error("DAVE: Missing/invalid proposals payload (#{inspect(reason)})")
        {manager, []}

      {:process_proposals, {:error, reason}} ->
        Logger.error("DAVE: Failed to process proposals: #{inspect(reason)}")
        {manager, []}
    end
  end

  # OP 29: DAVE_MLS_ANNOUNCE_COMMIT_TRANSITION
  def handle_mls_event(%__MODULE__{mls_session: session} = manager, 29, data)
      when not is_nil(session) do
    transition_id = normalize_integer(data["transition_id"], 0)

    case raw_or_base64(data, "commit_bin", "commit") do
      {:ok, commit} ->
        case mls_result(Native.process_commit(session, commit)) do
          :ok ->
            joined_transition(manager, session, transition_id, "Commit processed")

          {:error, reason} ->
            Logger.warning(
              "DAVE: Commit for transition #{transition_id} refused (#{inspect(reason)}), " <>
                "re-initialising"
            )

            recover_from_invalid_transition(manager, transition_id)
        end

      {:error, reason} ->
        Logger.error("DAVE: Missing/invalid commit payload (#{inspect(reason)})")
        {manager, []}
    end
  end

  # OP 30: DAVE_MLS_WELCOME
  def handle_mls_event(%__MODULE__{mls_session: session} = manager, 30, data)
      when not is_nil(session) do
    transition_id = normalize_integer(data["transition_id"], 0)

    case raw_or_base64(data, "welcome_bin", "welcome") do
      {:ok, welcome} ->
        case process_welcome(session, transition_id, welcome) do
          :ok ->
            joined_transition(manager, session, transition_id, "Welcome processed")

          {:error, :already_in_group} ->
            # Expected, not a fault: the session joined through its own commit before this welcome,
            # prepared by another member for the same transition, arrived. Discord still counts us
            # as joining through the welcome, so the session re-initialises and is added again.
            Logger.debug(
              "DAVE: Welcome for transition #{transition_id} arrived after joining through our " <>
                "own commit, re-initialising"
            )

            recover_from_invalid_transition(manager, transition_id)

          {:error, reason} ->
            Logger.warning(
              "DAVE: Welcome for transition #{transition_id} refused (#{inspect(reason)}), " <>
                "re-initialising"
            )

            recover_from_invalid_transition(manager, transition_id)
        end

      {:error, reason} ->
        Logger.error("DAVE: Missing/invalid welcome payload (#{inspect(reason)})")
        {manager, []}
    end
  end

  # OP 21: DAVE_PREPARE_TRANSITION
  #
  # Transition 0 is a (re)initialisation and executes at once, with nothing to acknowledge. Any other
  # transition is acknowledged, and a pending downgrade to protocol 0 starts accepting unencrypted
  # frames straight away, since other members may switch before the transition executes.
  def handle_mls_event(manager, 21, data) do
    transition_id = normalize_integer(data["transition_id"], 0)
    version = normalize_integer(data["protocol_version"], manager.protocol_version)
    Logger.debug("DAVE: Prepare transition #{transition_id}, version=#{version}")

    manager = put_in(manager.pending_transitions[transition_id], version)

    if transition_id == 0 do
      {execute_transition(manager, 0), []}
    else
      if version == 0, do: set_passthrough(manager, @pending_downgrade_expiry)
      {manager, [Payload.dave_ready_for_transition(transition_id)]}
    end
  end

  # OP 22: DAVE_EXECUTE_TRANSITION
  def handle_mls_event(manager, 22, data) do
    transition_id = normalize_integer(data["transition_id"], 0)
    {execute_transition(manager, transition_id), []}
  end

  # OP 24: DAVE_PREPARE_EPOCH
  #
  # Epoch 1 means a new group: the session re-initialises for the announced protocol version and
  # offers a fresh key package.
  def handle_mls_event(manager, 24, %{"epoch" => 1} = data) do
    version = normalize_integer(data["protocol_version"], manager.protocol_version)
    Logger.info("DAVE: Prepare epoch 1 (new group), protocol version #{version}")

    manager |> set_version(version) |> reinit_session()
  end

  def handle_mls_event(manager, 24, data) do
    Logger.debug("DAVE: Prepare epoch #{data["epoch"]}")
    {manager, []}
  end

  # OP 31 is sent by clients, not the gateway; log it rather than guess at a meaning.
  def handle_mls_event(manager, 31, data) do
    Logger.warning("DAVE: Invalid commit reported: #{inspect(data)}")
    {manager, []}
  end

  # Fallback for unhandled opcodes or nil session
  def handle_mls_event(manager, opcode, _data) do
    Logger.debug("DAVE: Unhandled MLS opcode #{opcode}")
    {manager, []}
  end

  @doc """
  Returns true when `after` executed a transition that `before` had not, leaving DAVE in effect.

  This is when `VOICE_DAVE_READY` is dispatched: a transition to protocol 0 is not one.
  """
  @spec transitioned_to_dave?(t(), t()) :: boolean()
  def transitioned_to_dave?(
        %__MODULE__{transitions: before},
        %__MODULE__{transitions: now} = after_
      ) do
    now > before and current_version(after_) > 0
  end

  # Commit or welcome accepted. Transition 0 needs no acknowledgement and counts as executed;
  # any other is acknowledged and executes on OP 22, at the version now in effect.
  defp joined_transition(manager, session, transition_id, action) do
    epoch = normalize_epoch_result(Native.get_epoch(session))
    Logger.info("DAVE: #{action}, transition #{transition_id}, epoch=#{epoch}")
    :telemetry.execute([:eda, :voice, :dave, :epoch_change], %{epoch: epoch}, %{})

    if transition_id == 0 do
      {%{
         manager
         | reinitializing: false,
           last_transition_id: 0,
           transitions: manager.transitions + 1
       }, []}
    else
      manager = put_in(manager.pending_transitions[transition_id], manager.protocol_version)
      {manager, [Payload.dave_ready_for_transition(transition_id)]}
    end
  end

  defp execute_transition(manager, transition_id) do
    case Map.pop(manager.pending_transitions, transition_id) do
      {nil, _} ->
        Logger.debug("DAVE: Execute transition #{transition_id}, but none is pending")
        manager

      {version, pending} ->
        old_version = manager.protocol_version
        manager = %{manager | pending_transitions: pending}

        manager =
          cond do
            version != old_version and version == 0 ->
              Logger.info(
                "DAVE: Downgraded to protocol 0, media is no longer end-to-end encrypted"
              )

              %{manager | downgraded: true}

            transition_id > 0 and manager.downgraded ->
              Logger.info("DAVE: Upgraded back to protocol #{version}")
              set_passthrough(manager, @transition_expiry)
              %{manager | downgraded: false}

            true ->
              manager
          end

        Logger.info("DAVE: Executed transition #{transition_id} (v#{old_version} -> v#{version})")

        %{
          set_version(manager, version)
          | reinitializing: false,
            last_transition_id: transition_id,
            transitions: manager.transitions + 1
        }
    end
  end

  defp set_version(manager, version) do
    if manager.version_ref, do: :atomics.put(manager.version_ref, 1, version)
    %{manager | protocol_version: version}
  end

  defp set_passthrough(%__MODULE__{mls_session: nil}, _expiry), do: :ok

  defp set_passthrough(%__MODULE__{mls_session: session}, expiry),
    do: Native.set_passthrough_mode(session, true, expiry)

  # Re-initialises the MLS session for the version in effect. Unlike `reset`, `reinit` also prepares
  # a new pending group, so the session can commit again if the next proposals call for it.
  defp reinit_session(%__MODULE__{protocol_version: 0, mls_session: nil} = manager),
    do: {manager, []}

  defp reinit_session(%__MODULE__{protocol_version: 0, mls_session: session} = manager) do
    Native.reset(session)
    set_passthrough(manager, @transition_expiry)
    {manager, []}
  end

  defp reinit_session(%__MODULE__{mls_session: nil} = manager) do
    case safe_new_session(manager.protocol_version, manager.user_id, manager.channel_id) do
      {:ok, ref} when is_reference(ref) -> send_key_package(%{manager | mls_session: ref})
      ref when is_reference(ref) -> send_key_package(%{manager | mls_session: ref})
      _ -> {manager, []}
    end
  end

  defp reinit_session(%__MODULE__{mls_session: session} = manager) do
    case mls_result(
           Native.reinit(session, manager.protocol_version, manager.user_id, manager.channel_id)
         ) do
      :ok ->
        send_key_package(manager)

      {:error, reason} ->
        Logger.error("DAVE: Failed to re-initialise the session (#{inspect(reason)})")
        {manager, []}
    end
  end

  defp send_key_package(manager) do
    case key_package_payload(manager) do
      {:ok, payload} ->
        Logger.debug("DAVE: Sending new key package")
        {manager, [payload]}

      :error ->
        Logger.error("DAVE: Failed to create key package")
        {manager, []}
    end
  end

  # Tell the gateway the transition failed (OP 31) and re-initialise with a fresh key package, so we
  # are removed and added again. Only once per failure: further commits or welcomes that fail while
  # the session is already re-initialising would otherwise each trigger another round.
  defp recover_from_invalid_transition(
         %__MODULE__{reinitializing: true} = manager,
         _transition_id
       ),
       do: {manager, []}

  defp recover_from_invalid_transition(manager, transition_id) do
    {manager, replies} = reinit_session(%{manager | reinitializing: true})
    {manager, [Payload.dave_mls_invalid_commit_welcome(transition_id) | replies]}
  end

  defp process_welcome(session, transition_id, welcome) do
    Logger.debug(
      "DAVE: Processing welcome transition_id=#{transition_id} size=#{byte_size(welcome)}"
    )

    mls_result(process_welcome_with_timeout(session, welcome))
  end

  # Commit, welcome and reinit results: `:ok`, `{:error, reason}`, or — from older NIF builds — a bare
  # `:error`.
  defp mls_result(:ok), do: :ok
  defp mls_result({:ok, :ok}), do: :ok
  defp mls_result({:error, reason}), do: {:error, reason}
  defp mls_result(other), do: {:error, other}

  defp proposal_operation_type(operation_type) do
    case normalize_integer(operation_type, 0) do
      1 -> :revoke
      _ -> :append
    end
  end

  defp proposals_reply(manager, commit, welcome) when byte_size(commit) > 0 do
    Logger.debug(
      "DAVE: Proposals processed, sending commit (#{byte_size(commit)} bytes)" <>
        welcome_log_suffix(welcome)
    )

    {manager, [Payload.dave_mls_commit_welcome(commit, welcome)]}
  end

  defp proposals_reply(manager, _commit, _welcome) do
    Logger.debug("DAVE: Proposals processed, no commit needed")
    {manager, []}
  end

  defp welcome_log_suffix(welcome) when is_binary(welcome),
    do: " + welcome (#{byte_size(welcome)} bytes)"

  defp welcome_log_suffix(_welcome), do: ""

  defp raw_or_base64(data, raw_key, base64_key) do
    cond do
      is_binary(data[raw_key]) ->
        {:ok, data[raw_key]}

      is_binary(data[base64_key]) ->
        case Base.decode64(data[base64_key]) do
          {:ok, decoded} -> {:ok, decoded}
          :error -> {:error, :invalid_base64}
        end

      true ->
        {:error, :missing_payload}
    end
  end

  defp connected_clients_to_ids(%MapSet{} = clients) do
    Enum.map(clients, fn id ->
      case Integer.parse(to_string(id)) do
        {int, ""} -> int
        _ -> 0
      end
    end)
  end

  defp connected_clients_to_ids(_), do: []

  defp normalize_integer(value, _fallback) when is_integer(value), do: value

  defp normalize_integer(value, fallback) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> fallback
    end
  end

  defp normalize_integer(_value, fallback), do: fallback

  defp normalize_key_package_result({:ok, key_package}) when is_binary(key_package),
    do: {:ok, key_package}

  defp normalize_key_package_result({:ok, {:ok, key_package}}) when is_binary(key_package),
    do: {:ok, key_package}

  defp normalize_key_package_result(other), do: {:error, other}

  defp normalize_process_proposals_result({:ok, commit, welcome})
       when is_binary(commit) and (is_binary(welcome) or is_nil(welcome)),
       do: {:ok, commit, welcome}

  defp normalize_process_proposals_result({:ok, {:ok, commit, welcome}})
       when is_binary(commit) and (is_binary(welcome) or is_nil(welcome)),
       do: {:ok, commit, welcome}

  defp normalize_process_proposals_result(other), do: {:error, other}

  defp normalize_encrypt_result({:ok, encrypted}) when is_binary(encrypted), do: {:ok, encrypted}

  defp normalize_encrypt_result({:ok, {:ok, encrypted}}) when is_binary(encrypted),
    do: {:ok, encrypted}

  defp normalize_encrypt_result({:error, reason}), do: {:error, reason}
  defp normalize_encrypt_result(other), do: {:error, other}

  defp normalize_decrypt_result({:ok, decrypted}) when is_binary(decrypted), do: {:ok, decrypted}

  defp normalize_decrypt_result({:ok, {:ok, decrypted}}) when is_binary(decrypted),
    do: {:ok, decrypted}

  defp normalize_decrypt_result(other), do: {:error, other}

  defp normalize_ready_result({:ok, ready}) when is_boolean(ready), do: {:ok, ready}
  defp normalize_ready_result(ready) when is_boolean(ready), do: {:ok, ready}
  defp normalize_ready_result(other), do: {:error, other}

  defp normalize_epoch_result({:ok, epoch}) when is_integer(epoch), do: epoch
  defp normalize_epoch_result(epoch) when is_integer(epoch), do: epoch
  defp normalize_epoch_result(_), do: 0

  defp process_welcome_with_timeout(session, payload) do
    task = Task.async(fn -> Native.process_welcome(session, payload) end)

    case Task.yield(task, 2_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil -> :timeout
    end
  end

  # Without the NIF the stub raises rather than returning, and the fallback above only
  # handles returned values. Voice/event.ex already avoids advertising DAVE in that case;
  # this keeps a stray call from taking the voice session down with it.
  defp safe_new_session(protocol_version, user_id, channel_id) do
    Native.new_session(protocol_version, user_id, channel_id)
  rescue
    e in ErlangError -> {:error, e.original}
  end
end
