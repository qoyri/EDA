defmodule EDA.Voice.Dave.NativeLoader do
  @moduledoc false

  # Loads the DAVE NIF: a precompiled binary downloaded at compile time, or a build from source.
  #
  # Precompiled is the default, so a bot needs no Rust toolchain. Building from source happens in
  # EDA's own dev and test environments, or when asked for — `config :rustler_precompiled,
  # :force_build, eda: true` or `RUSTLER_PRECOMPILED_FORCE_BUILD_ALL=1` — and needs `:rustler`.
  #
  # Unlike `use RustlerPrecompiled`, a failure does not fail compilation. A platform without a
  # precompiled binary, a machine offline at compile time, or a version whose binaries are not
  # published yet leaves the module with its stubs and a compile-time warning: EDA still compiles,
  # and only voice is affected — Discord then refuses it with close code 4017, which EDA reports.
  # That keeps the guarantee that a bot which never joins voice builds anywhere.
  #
  # `RustlerPrecompiled.__using__/2` is the function `use RustlerPrecompiled` itself calls; it is
  # called directly so that its `{:error, _}` can be handled instead of raised.
  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      opts =
        if Application.compile_env(
             :rustler_precompiled,
             :force_build_all,
             System.get_env("RUSTLER_PRECOMPILED_FORCE_BUILD_ALL") in ["1", "true"]
           ) do
          Keyword.put(opts, :force_build, true)
        else
          Keyword.update!(opts, :force_build, fn default ->
            Application.compile_env(:rustler_precompiled, [:force_build, :eda], default)
          end)
        end

      case RustlerPrecompiled.__using__(__MODULE__, opts) do
        {:ok, config} ->
          @on_load :load_rustler_precompiled
          @rustler_precompiled_load_from config.load_from
          @rustler_precompiled_load_data config.load_data

          @doc false
          def load_rustler_precompiled do
            # Purge any old copy, or loading fails with "Upgrade not supported by this NIF library".
            :code.purge(__MODULE__)
            {otp_app, path} = @rustler_precompiled_load_from

            otp_app
            |> Application.app_dir(path)
            |> to_charlist()
            |> :erlang.load_nif(@rustler_precompiled_load_data)
          end

        {:force_build, rustler_opts} ->
          unquote(force_build())

        {:error, message} ->
          IO.warn(
            "[EDA] The DAVE NIF is not available, so voice will be refused by Discord " <>
              "(close code 4017). EDA itself works normally.\n\n" <> message,
            []
          )
      end
    end
  end

  # `use Rustler` must only be emitted when Rustler exists: it is an optional dependency, and a
  # macro inside an `if` is expanded either way.
  defp force_build do
    if Code.ensure_loaded?(Rustler) do
      quote do
        use Rustler, rustler_opts
      end
    else
      quote do
        IO.warn(
          "[EDA] Building the DAVE NIF from source needs Rustler: add {:rustler, \"~> 0.35\"} " <>
            "to your deps. Voice will be refused by Discord (close code 4017) until then.",
          []
        )
      end
    end
  end
end
