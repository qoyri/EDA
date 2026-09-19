defmodule EDA.Voice.Dave.Native do
  @moduledoc """
  NIF bindings for the DAVE (Discord Audio Video E2EE) MLS session.

  Wraps the `davey` Rust crate which implements the MLS (RFC 9420) key
  exchange protocol used by Discord's DAVE protocol.

  The NIF is compiled and loaded automatically via Rustler when Rust is
  available. If the NIF cannot be loaded, all functions raise `:nif_not_loaded`
  and `available?/0` returns false.
  """

  use Rustler, otp_app: :eda, crate: "eda_dave"

  # Return shapes: the Rust side returns `Result<T, Atom>`, and Rustler encodes that
  # as `{:ok, T}` / `{:error, atom}`. For the NIFs whose `T` is itself an `{:ok, ...}`
  # tuple (create_key_package, process_proposals, encrypt_opus, decrypt_audio) the
  # result is therefore DOUBLE-wrapped: `{:ok, {:ok, binary}}`. Verified against the
  # loaded NIF on 2026-09-19. EDA.Voice.Dave.Manager normalises both shapes; the
  # single-wrapped form is kept in these specs so that defensive handling stays valid.
  #
  # The same applies to the plain getters (ready?/1, get_epoch/1, status/1,
  # can_passthrough?/2, protocol_version/1): their Rust side also returns `Result`,
  # so they yield `{:ok, value}`, NOT the bare value. Only max_protocol_version/0
  # returns a bare `u16`.

  @doc "Creates a new MLS session for the given protocol version, user ID, and channel ID."
  @spec new_session(pos_integer(), non_neg_integer(), non_neg_integer()) ::
          {:ok, reference()} | {:error, atom()} | reference() | no_return()
  def new_session(_protocol_version, _user_id, _channel_id),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc "Creates and returns the client's MLS key package as `{:ok, binary}`."
  @spec create_key_package(reference()) ::
          {:ok, {:ok, binary()}} | {:ok, binary()} | {:error, atom()}
  def create_key_package(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Sets the external sender credential (from the voice gateway)."
  @spec set_external_sender(reference(), binary()) :: :ok | :error
  def set_external_sender(_ref, _credential), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Processes MLS proposals from the gateway.

  `operation_type` is `:append` or `:revoke`.
  `user_ids` is a list of connected client user IDs (integers).
  Returns `{:ok, commit_binary, welcome_binary_or_nil}`.
  """
  @spec process_proposals(reference(), :append | :revoke, binary(), [non_neg_integer()]) ::
          {:ok, {:ok, binary(), binary() | nil}}
          | {:ok, binary(), binary() | nil}
          | {:error, atom()}
  def process_proposals(_ref, _operation_type, _proposals, _user_ids),
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
          {:ok, {:ok, binary()}}
          | {:ok, binary()}
          | {:error, :not_ready | :encryption_failed | :error}
  def encrypt_opus(_ref, _packet), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Decrypts a DAVE-encrypted audio packet. Returns `{:ok, decrypted_binary}`."
  @spec decrypt_audio(reference(), non_neg_integer(), binary()) ::
          {:ok, {:ok, binary()}} | {:ok, binary()} | {:error, atom()}
  def decrypt_audio(_ref, _sender_user_id, _packet), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Returns true if the user's decryptor has an active passthrough (epoch transition grace period)."
  @spec can_passthrough?(reference(), non_neg_integer()) ::
          {:ok, boolean()} | {:error, atom()} | boolean()
  def can_passthrough?(_ref, _user_id), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Returns the current MLS epoch number."
  @spec get_epoch(reference()) ::
          {:ok, non_neg_integer()} | {:error, atom()} | non_neg_integer()
  def get_epoch(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Returns true if the MLS session is ready (group established)."
  @spec ready?(reference()) :: {:ok, boolean()} | {:error, atom()} | boolean()
  def ready?(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Sets passthrough mode (disable/enable E2EE without destroying the session)."
  @spec set_passthrough_mode(reference(), boolean()) :: :ok | :error
  def set_passthrough_mode(_ref, _passthrough), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Resets the MLS group state without losing key material or external sender."
  @spec reset(reference()) :: :ok | :error
  def reset(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Re-initializes the session with new parameters without creating a new resource."
  @spec reinit(reference(), pos_integer(), non_neg_integer(), non_neg_integer()) :: :ok | :error
  def reinit(_ref, _protocol_version, _user_id, _channel_id),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc "Returns the session status: `:inactive`, `:pending`, `:awaiting_response`, or `:active`."
  @spec status(reference()) ::
          {:ok, :inactive | :pending | :awaiting_response | :active}
          | {:error, atom()}
          | :inactive
          | :pending
          | :awaiting_response
          | :active
  def status(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Returns the DAVE protocol version of this session."
  @spec protocol_version(reference()) ::
          {:ok, pos_integer()} | {:error, atom()} | pos_integer()
  def protocol_version(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Returns the maximum DAVE protocol version supported by the davey crate."
  @spec max_protocol_version() :: pos_integer()
  def max_protocol_version, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Returns true if the NIF is loaded and available."
  @spec available?() :: boolean()
  def available? do
    new_session(1, 0, 0)
    true
  rescue
    _ -> false
  end
end
