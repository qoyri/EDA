defmodule EDA.Gateway.CompressionTest do
  # NOT async — reads the :eda application env.
  use ExUnit.Case

  alias EDA.Gateway.Compression

  setup do
    previous = Application.get_env(:eda, :gateway_compression)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:eda, :gateway_compression, previous),
        else: Application.delete_env(:eda, :gateway_compression)
    end)

    :ok
  end

  test "uses zstd-stream by default when the NIF is loaded" do
    Application.delete_env(:eda, :gateway_compression)
    assert Compression.module() == EDA.Gateway.Zstd
    assert Compression.url_param(EDA.Gateway.Zstd) == "zstd-stream"
  end

  test "zlib-stream can be chosen" do
    Application.put_env(:eda, :gateway_compression, :zlib)
    assert Compression.module() == EDA.Gateway.Zlib
    assert Compression.url_param(EDA.Gateway.Zlib) == "zlib-stream"
  end
end
