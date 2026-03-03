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

  @doc """
  Encrypts an Opus frame through DAVE E2EE.

  In passthrough mode, returns the frame unchanged.
  Returns `{encrypted_frame, updated_manager}`.
  """
  @spec encrypt_frame(t(), binary()) :: {binary(), t()}
  def encrypt_frame(%__MODULE__{mls_session: nil} = manager, opus_frame) do
    {opus_frame, manager}
  end

  def encrypt_frame(%__MODULE__{mls_session: session} = manager, opus_frame) do
    case Native.encrypt_opus(session, opus_frame) do
      {:ok, encrypted} ->
        {encrypted, manager}

      {:error, :not_ready} ->
        Logger.debug("DAVE: encrypt_opus not ready, sending unencrypted")
        {opus_frame, manager}

      {:error, reason} ->
        Logger.debug("DAVE: encrypt_opus failed (#{inspect(reason)}), sending unencrypted")
        {opus_frame, manager}

      _ ->
        Logger.debug("DAVE: encrypt_opus failed, sending unencrypted")
        {opus_frame, manager}
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
    case Native.decrypt_audio(session, sender_user_id, frame) do
      {:ok, decrypted} ->
        {:ok, decrypted, manager}

      _ ->
        :telemetry.execute([:eda, :voice, :dave, :frame_decrypt_error], %{count: 1}, %{
          user_id: sender_user_id
        })

        {:error, :decrypt_failed}
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
    case raw_or_base64(data, "external_sender_bin", "external_sender") do
      {:ok, credential} ->
        case Native.set_external_sender(session, credential) do
          :ok ->
            Logger.debug("DAVE: External sender set")
            # After setting external sender, send our key package
            case normalize_key_package_result(Native.create_key_package(session)) do
              {:ok, key_package} ->
                Logger.debug("DAVE: Sending MLS key package (#{byte_size(key_package)} bytes)")
                {manager, [Payload.dave_mls_key_package(key_package)]}

              {:error, reason} ->
                Logger.error("DAVE: Failed to create key package: #{inspect(reason)}")
                {manager, []}
            end

          :error ->
            Logger.error("DAVE: Failed to set external sender")
            {manager, []}
        end

      {:error, reason} ->
        Logger.error("DAVE: Missing/invalid external sender payload (#{inspect(reason)})")
        {manager, []}
    end
  end

  # OP 27: DAVE_MLS_PROPOSALS
  def handle_mls_event(%__MODULE__{mls_session: session} = manager, 27, data)
      when not is_nil(session) do
    op_type =
      case normalize_integer(data["operation_type"], 0) do
        1 -> :revoke
        _ -> :append
      end

    case raw_or_base64(data, "proposals_bin", "proposals") do
      {:ok, proposals} ->
        case normalize_process_proposals_result(
               Native.process_proposals(session, op_type, proposals)
             ) do
          {:ok, commit, welcome} when byte_size(commit) > 0 ->
            Logger.debug(
              "DAVE: Proposals processed, sending commit (#{byte_size(commit)} bytes)" <>
                if(is_binary(welcome), do: " + welcome (#{byte_size(welcome)} bytes)", else: "")
            )

            {manager, [Payload.dave_mls_commit_welcome(commit, welcome)]}

          {:ok, _empty, _} ->
            Logger.debug("DAVE: Proposals processed, no commit needed")
            {manager, []}

          {:error, reason} ->
            Logger.error("DAVE: Failed to process proposals: #{inspect(reason)}")
            {manager, []}
        end

      {:error, reason} ->
        Logger.error("DAVE: Missing/invalid proposals payload (#{inspect(reason)})")
        {manager, []}
    end
  end

  # OP 29: DAVE_MLS_ANNOUNCE_COMMIT
  def handle_mls_event(%__MODULE__{mls_session: session} = manager, 29, data)
      when not is_nil(session) do
    transition_id = normalize_integer(data["transition_id"], 0)

    case raw_or_base64(data, "commit_bin", "commit") do
      {:ok, commit} ->
        case Native.process_commit(session, commit) do
          :ok ->
            epoch = Native.get_epoch(session)
            Logger.info("DAVE: Commit processed, epoch=#{epoch}")

            :telemetry.execute([:eda, :voice, :dave, :epoch_change], %{epoch: epoch}, %{})

            manager = %{manager | transition_id: transition_id, pending_epoch: epoch}
            {manager, [Payload.dave_ready_for_transition(transition_id)]}

          :error ->
            Logger.error("DAVE: Failed to process commit")
            {manager, []}
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
        case Native.process_welcome(session, welcome) do
          :ok ->
            epoch = Native.get_epoch(session)
            Logger.info("DAVE: Welcome processed, epoch=#{epoch}")

            :telemetry.execute([:eda, :voice, :dave, :epoch_change], %{epoch: epoch}, %{})

            manager = %{manager | transition_id: transition_id, pending_epoch: epoch}
            {manager, [Payload.dave_ready_for_transition(transition_id)]}

          :error ->
            Logger.error("DAVE: Failed to process welcome")
            {manager, []}
        end

      {:error, reason} ->
        Logger.error("DAVE: Missing/invalid welcome payload (#{inspect(reason)})")
        {manager, []}
    end
  end

  # OP 21: DAVE_PREPARE_TRANSITION
  def handle_mls_event(manager, 21, data) do
    Logger.debug("DAVE: Prepare transition, version=#{data["protocol_version"]}")
    {manager, []}
  end

  # OP 22: DAVE_EXECUTE_TRANSITION
  def handle_mls_event(manager, 22, _data) do
    Logger.info("DAVE: Execute transition, epoch=#{manager.pending_epoch}")
    {%{manager | pending_epoch: nil, transition_id: nil}, []}
  end

  # OP 24: DAVE_PREPARE_EPOCH
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
end
