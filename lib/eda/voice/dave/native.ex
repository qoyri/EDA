defmodule EDA.Voice.Dave.Native do
  @moduledoc """
  NIF bindings for the DAVE (Discord Audio Video E2EE) MLS session.

  Wraps the `davey` Rust crate which implements the MLS (RFC 9420) key
  exchange protocol used by Discord's DAVE protocol. The same NIF also carries the gateway's
  zstd-stream decompression, used through `EDA.Gateway.Zstd`.

  The NIF is downloaded precompiled when EDA compiles, from the GitHub release of EDA's version,
  and verified against the checksums shipped in the package. Binaries exist for Linux (x86-64,
  ARM64, ARMv7, RISC-V; glibc and musl), macOS, Windows and FreeBSD, so no Rust toolchain is needed.

  ## Building from source

  On another platform, or without network access at compile time, build it from source. That needs
  Rust and Rustler:

      {:rustler, "~> 0.35"}

      config :rustler_precompiled, :force_build, eda: true

  ## Without the NIF

  If the NIF can be neither downloaded nor built, EDA still compiles, with a warning, and this
  module keeps its stubs: every function raises `:nif_not_loaded` and `available?/0` returns false.
  Voice is then connected without offering DAVE, which Discord refuses with close code 4017 —
  it has required DAVE since March 2026 for DMs, group DMs, voice channels and Go Live; only Stage
  channels are exempt.
  """

  # See EDA.Voice.Dave.NativeLoader for how the NIF is obtained, and why failing to obtain it does
  # not fail compilation.
  version = Mix.Project.config()[:version]

  use EDA.Voice.Dave.NativeLoader,
    otp_app: :eda,
    crate: "eda_dave",
    base_url: "https://github.com/qoyri/EDA/releases/download/v#{version}",
    version: version,
    targets: ["x86_64-unknown-freebsd" | RustlerPrecompiled.Config.default_targets()],
    nif_versions: ["2.15"],
    # EDA's own dev and test environments build the NIF they are working on. As a dependency,
    # EDA is compiled in :prod and downloads the binary published for its version.
    force_build: Mix.env() in [:dev, :test]

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

  @doc """
  Processes an MLS commit from the gateway.

  A failure names its cause: `:no_group` or `:pending_group` when the session has not joined a group
  the commit could apply to, `:invalid` otherwise.
  """
  @spec process_commit(reference(), binary()) ::
          :ok | :error | {:error, :no_group | :pending_group | :invalid}
  def process_commit(_ref, _commit), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Processes an MLS welcome message from the gateway.

  A failure names its cause: `:already_in_group` when the session had already joined through a
  commit of its own — the expected outcome of a commit race — `:no_external_sender`, or `:invalid`.
  """
  @spec process_welcome(reference(), binary()) ::
          :ok | :error | {:error, :already_in_group | :no_external_sender | :invalid}
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

  @doc """
  Sets passthrough mode on every decryptor: while it is on, unencrypted frames are accepted.

  Turning it on is immediate; `transition_expiry` is how many seconds decryptors keep accepting
  unencrypted frames once it is turned off again.
  """
  @spec set_passthrough_mode(reference(), boolean(), non_neg_integer()) :: :ok | :error
  def set_passthrough_mode(_ref, _passthrough, _transition_expiry),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Leaves the MLS group and clears the session's key storage, keeping the external sender.

  It does not prepare a new pending group, so a session that must commit again needs `reinit/4`.
  """
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

  # ── Gateway transport compression ──
  #
  # zstd-stream decompression for the gateway, in this NIF because it is the one EDA already
  # ships precompiled. Used through EDA.Gateway.Zstd.

  @doc false
  @spec zstd_new() :: {:ok, reference()} | {:error, atom()}
  def zstd_new, do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  @spec zstd_decompress(reference(), binary()) :: {:ok, binary()} | {:error, atom()}
  def zstd_decompress(_ref, _input), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  @spec zstd_decompress_dirty(reference(), binary()) :: {:ok, binary()} | {:error, atom()}
  def zstd_decompress_dirty(_ref, _input), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  @spec zstd_reset(reference()) :: :ok | :error
  def zstd_reset(_ref), do: :erlang.nif_error(:nif_not_loaded)
end
