defmodule EDA.Voice.Dave.NativeLoader do
  @moduledoc false

  # Emits `use Rustler` only when Rustler is present.
  #
  # `:rustler` is an optional dependency, so a consumer who did not add it has no Rustler
  # module. Wrapping `use Rustler` in an `if` inside the NIF module does not help: macros in
  # both branches of an `if` are expanded at compile time, so the false branch still needs
  # Rustler to exist. The check has to happen here, when this macro is expanded, so that the
  # `use` is never emitted at all.
  defmacro __using__(opts) do
    if Code.ensure_loaded?(Rustler) do
      quote do
        use Rustler, unquote(opts)
      end
    end
  end
end
