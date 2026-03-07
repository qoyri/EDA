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

  defstruct [
    :mls_session,
    :protocol_version,
    :user_id,
    :channel_id,
    :transition_id,
    pending_epoch: nil
  ]

  @type t :: %__MODULE__{
          mls_session: reference() | nil,
          protocol_version: non_neg_integer(),
          user_id: non_neg_integer(),
          channel_id: non_neg_integer(),
          transition_id: non_neg_integer() | nil,
          pending_epoch: non_neg_integer() | nil
        }

  @doc "Creates a new DAVE manager. Version 0 means passthrough (no E2EE)."
  @spec new(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def new(protocol_version, user_id, channel_id) do
    session =
      if protocol_version > 0 do
        case Native.new_session(protocol_version, user_id, channel_id) do
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

    %__MODULE__{
      mls_session: session,
      protocol_version: protocol_version,
      user_id: user_id,
      channel_id: channel_id
    }
  end

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
    case normalize_encrypt_result(Native.encrypt_opus(session, opus_frame)) do
      {:ok, encrypted} ->
        {:ok, encrypted, manager}

      {:error, :not_ready} ->
        Logger.warning("DAVE: encrypt_opus not ready, aborting media send")
        {:error, :not_ready, manager}

      {:error, reason} ->
        Logger.warning("DAVE: encrypt_opus failed (#{inspect(reason)}), aborting media send")
        {:error, reason, manager}

      other ->
        Logger.warning("DAVE: encrypt_opus failed (#{inspect(other)}), aborting media send")
        {:error, other, manager}
    end
  end

  @doc """
  Decrypts a DAVE-encrypted frame.

  In passthrough mode, returns the frame unchanged.
  Returns `{:ok, decrypted_frame, updated_manager}` or `{:error, reason}`.
  """
  @spec decrypt_frame(t(), binary(), non_neg_integer()) ::
          {:ok, binary(), t()} | {:error, atom()}
  def decrypt_frame(%__MODULE__{mls_session: nil} = manager, frame, _sender_user_id) do
    {:ok, frame, manager}
  end

  def decrypt_frame(%__MODULE__{mls_session: session} = manager, frame, sender_user_id) do
    case normalize_decrypt_result(Native.decrypt_audio(session, sender_user_id, frame)) do
      {:ok, decrypted} ->
        {:ok, decrypted, manager}

      _ ->
        if Native.can_passthrough?(session, sender_user_id) do
          {:ok, frame, manager}
        else
          :telemetry.execute([:eda, :voice, :dave, :frame_decrypt_error], %{count: 1}, %{
            user_id: sender_user_id
          })

          {:error, :decrypt_failed}
        end
    end
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
  def handle_mls_event(%__MODULE__{mls_session: session} = manager, 25, data)
      when not is_nil(session) do
    with {:ok, credential} <- raw_or_base64(data, "external_sender_bin", "external_sender"),
         :ok <- Native.set_external_sender(session, credential),
         {:key_package, {:ok, key_package}} <-
           {:key_package, normalize_key_package_result(Native.create_key_package(session))} do
      Logger.debug("DAVE: External sender set")
      Logger.debug("DAVE: Sending MLS key package (#{byte_size(key_package)} bytes)")
      {manager, [Payload.dave_mls_key_package(key_package)]}
    else
      {:error, reason} ->
        Logger.error("DAVE: Missing/invalid external sender payload (#{inspect(reason)})")
        {manager, []}

      :error ->
        Logger.error("DAVE: Failed to set external sender")
        {manager, []}

      {:key_package, {:error, reason}} ->
        Logger.error("DAVE: Failed to create key package: #{inspect(reason)}")
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

  # OP 29: DAVE_MLS_ANNOUNCE_COMMIT
  def handle_mls_event(%__MODULE__{mls_session: session} = manager, 29, data)
      when not is_nil(session) do
    transition_id = normalize_integer(data["transition_id"], 0)

    with {:ok, commit} <- raw_or_base64(data, "commit_bin", "commit"),
         raw_result <- Native.process_commit(session, commit),
         {:process_commit, :ok, _} <-
           {:process_commit, normalize_atom_result(raw_result), raw_result} do
      announce_transition_ready(manager, session, transition_id, "Commit processed")
    else
      {:error, reason} ->
        Logger.error("DAVE: Missing/invalid commit payload (#{inspect(reason)})")
        {manager, []}

      {:process_commit, :error, raw_result} ->
        Logger.error("DAVE: Failed to process commit result=#{inspect(raw_result)}")
        {manager, []}
    end
  end

  # OP 30: DAVE_MLS_WELCOME
  def handle_mls_event(%__MODULE__{mls_session: session} = manager, 30, data)
      when not is_nil(session) do
    transition_id = normalize_integer(data["transition_id"], 0)

    with {:ok, welcome} <- raw_or_base64(data, "welcome_bin", "welcome"),
         {:process_welcome, :ok, _detail} <- process_welcome(session, transition_id, welcome) do
      announce_transition_ready(manager, session, transition_id, "Welcome processed")
    else
      {:error, reason} ->
        Logger.error("DAVE: Missing/invalid welcome payload (#{inspect(reason)})")
        {manager, []}

      {:process_welcome, :error, _detail} ->
        # Welcome unprocessable — signal gateway to remove and re-add us.
        Logger.warning("DAVE: Welcome failed, sending invalid_commit_welcome for recovery")
        recover_from_failed_welcome(manager, transition_id)
    end
  end

  # OP 21: DAVE_PREPARE_TRANSITION
  def handle_mls_event(manager, 21, %{"transition_id" => 0} = data) do
    # transition_id == 0 means boot-time, execute immediately
    Logger.debug("DAVE: Prepare transition (boot), version=#{data["protocol_version"]}")
    {manager, [Payload.dave_ready_for_transition(0)]}
  end

  def handle_mls_event(manager, 21, data) do
    Logger.debug("DAVE: Prepare transition, version=#{data["protocol_version"]}")
    {manager, []}
  end

  # OP 22: DAVE_EXECUTE_TRANSITION
  def handle_mls_event(manager, 22, _data) do
    Logger.info("DAVE: Execute transition, epoch=#{inspect(manager.pending_epoch)}")
    {%{manager | pending_epoch: nil, transition_id: nil}, []}
  end

  # OP 24: DAVE_PREPARE_EPOCH
  # epoch=1 means sole member reset — must reset group and send new key package
  def handle_mls_event(%__MODULE__{mls_session: session} = manager, 24, %{"epoch" => 1})
      when not is_nil(session) do
    Logger.info("DAVE: Prepare epoch 1 (sole member reset), resetting group")
    Native.reset(session)

    case normalize_key_package_result(Native.create_key_package(session)) do
      {:ok, key_package} ->
        Logger.debug("DAVE: Sending new key package after epoch=1 reset")
        {manager, [Payload.dave_mls_key_package(key_package)]}

      _ ->
        Logger.error("DAVE: Failed to create key package after epoch=1 reset")
        {manager, []}
    end
  end

  def handle_mls_event(manager, 24, data) do
    Logger.debug("DAVE: Prepare epoch #{data["epoch"]}")
    {manager, []}
  end

  # OP 31: DAVE_MLS_INVALID_COMMIT
  def handle_mls_event(manager, 31, data) do
    Logger.warning("DAVE: Invalid commit reported: #{inspect(data)}")
    {manager, []}
  end

  # Fallback for unhandled opcodes or nil session
  def handle_mls_event(manager, opcode, _data) do
    Logger.debug("DAVE: Unhandled MLS opcode #{opcode}")
    {manager, []}
  end

  defp process_welcome(session, transition_id, welcome) do
    Logger.debug(
      "DAVE: Processing welcome transition_id=#{transition_id} size=#{byte_size(welcome)}"
    )

    raw_result = process_welcome_with_timeout(session, welcome)
    status = normalize_atom_result(raw_result)

    if status == :ok do
      {:process_welcome, :ok, raw_result}
    else
      {:process_welcome, :error, %{raw: raw_result, status: status}}
    end
  end

  defp announce_transition_ready(manager, session, transition_id, action) do
    epoch = normalize_epoch_result(Native.get_epoch(session))
    Logger.info("DAVE: #{action}, epoch=#{epoch}")

    :telemetry.execute([:eda, :voice, :dave, :epoch_change], %{epoch: epoch}, %{})

    manager = %{manager | transition_id: transition_id, pending_epoch: epoch}
    {manager, [Payload.dave_ready_for_transition(transition_id)]}
  end

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

  defp normalize_atom_result({:ok, atom}) when is_atom(atom), do: atom
  defp normalize_atom_result(atom) when is_atom(atom), do: atom
  defp normalize_atom_result(_), do: :error

  defp normalize_epoch_result({:ok, epoch}) when is_integer(epoch), do: epoch
  defp normalize_epoch_result(epoch) when is_integer(epoch), do: epoch
  defp normalize_epoch_result(_), do: 0

  defp recover_from_failed_welcome(manager, transition_id) do
    session = manager.mls_session

    # Per Discord docs: send OP 31, reset state, send new key package.
    # The gateway will remove and re-add us with a fresh welcome.
    Native.reset(session)

    replies = [Payload.dave_mls_invalid_commit_welcome(transition_id)]

    # Send a fresh key package so the gateway can re-add us
    replies =
      case normalize_key_package_result(Native.create_key_package(session)) do
        {:ok, key_package} ->
          Logger.info("DAVE: Recovery — sending invalid_commit_welcome + new key package")
          replies ++ [Payload.dave_mls_key_package(key_package)]

        _ ->
          Logger.info("DAVE: Recovery — sending invalid_commit_welcome (no key package)")
          replies
      end

    {manager, replies}
  end

  defp process_welcome_with_timeout(session, payload) do
    task = Task.async(fn -> Native.process_welcome(session, payload) end)

    case Task.yield(task, 2_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil -> :timeout
    end
  end
end
