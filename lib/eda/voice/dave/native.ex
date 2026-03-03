defmodule EDA.Voice.Dave.Native do
  @moduledoc """
  NIF bindings for the DAVE (Discord Audio Video E2EE) MLS session.

  Wraps the `davey` Rust crate which implements the MLS (RFC 9420) key
  exchange protocol used by Discord's DAVE protocol.

  The NIF is loaded at runtime via `@on_load`. If the shared library is not
  found (e.g. Rustler was not available when EDA was compiled), all functions
  gracefully raise `:nif_not_loaded` and `available?/0` returns false.
  """

  @on_load :load_nif

  @doc false
  def load_nif do
    path =
      :eda
      |> :code.priv_dir()
      |> Path.join("native/eda_dave")

    case :erlang.load_nif(String.to_charlist(path), 0) do
      :ok ->
        :ok

      {:error, {:reload, _}} ->
        :ok

      {:error, reason} ->
        require Logger
        Logger.debug("DAVE NIF not available: #{inspect(reason)}")
        :ok
    end
  end

  @doc "Creates a new MLS session for the given protocol version, user ID, and channel ID."
  @spec new_session(pos_integer(), non_neg_integer(), non_neg_integer()) ::
          reference() | no_return()
  def new_session(_protocol_version, _user_id, _channel_id),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc "Creates and returns the client's MLS key package as `{:ok, binary}`."
  @spec create_key_package(reference()) :: {:ok, binary()}
  def create_key_package(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Sets the external sender credential (from the voice gateway)."
  @spec set_external_sender(reference(), binary()) :: :ok | :error
  def set_external_sender(_ref, _credential), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Processes MLS proposals from the gateway.

  `operation_type` is `:append` or `:revoke`.
  Returns `{:ok, commit_binary, :ok | :nil}` where the third element indicates
  whether a welcome message was generated.
  """
  @spec process_proposals(reference(), :append | :revoke, binary()) ::
          {:ok, binary(), :ok | nil}
  def process_proposals(_ref, _operation_type, _proposals),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc "Processes an MLS commit from the gateway."
  @spec process_commit(reference(), binary()) :: :ok | :error
  def process_commit(_ref, _commit), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Processes an MLS welcome message from the gateway."
  @spec process_welcome(reference(), binary()) :: :ok | :error
  def process_welcome(_ref, _welcome), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Encrypts an Opus audio packet using DAVE E2EE.

  Returns `{:ok, encrypted_binary}` or `{:error, :not_ready | :encryption_failed | :error}`.
  """
  @spec encrypt_opus(reference(), binary()) ::
          {:ok, binary()} | {:error, :not_ready | :encryption_failed | :error}
  def encrypt_opus(_ref, _packet), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Decrypts a DAVE-encrypted audio packet. Returns `{:ok, decrypted_binary}`."
  @spec decrypt_audio(reference(), non_neg_integer(), binary()) :: {:ok, binary()}
  def decrypt_audio(_ref, _sender_user_id, _packet), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Returns the current MLS epoch number."
  @spec get_epoch(reference()) :: non_neg_integer()
  def get_epoch(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Returns true if the MLS session is ready (group established)."
  @spec ready?(reference()) :: boolean()
  def ready?(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Sets passthrough mode (disable/enable E2EE without destroying the session)."
  @spec set_passthrough_mode(reference(), boolean()) :: :ok | :error
  def set_passthrough_mode(_ref, _passthrough), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Returns true if the NIF is loaded and available."
  @spec available?() :: boolean()
  def available? do
    new_session(1, 0, 0)
    true
  rescue
    _ -> false
  end
end
