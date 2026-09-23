defmodule EDA.Gateway.ZstdTest do
  use ExUnit.Case, async: true

  alias EDA.Gateway.Zstd

  # Two ETF payloads compressed as Discord sends zstd-stream: one context for the connection,
  # flushed after each message. The second frame refers back to the first, so it only
  # decompresses in the same context.
  @frame1 Base.decode64!(
            "KLUv/QBYPAIAMgQPGJA5Hf+3IixL67EBuJCvd3d3OJKvM4J2Cku184pLtfMUIRME+BnRPFq5uNSmimZCdZmO4Wf418CfBX+ZAgAgis1LQQE="
          )
  @frame2 Base.decode64!(
            "BAMAdAQDBWNvbG9yYgDPADFtAAAAB2NvbnRlbnRtAAAA3GhlbGxvIHpzdGQgaWRuCAABAALAHIcKEgBhAQ5NRVNTQUdFX0NSRUFURQgADSvitu7BYIOW/mVd4U4XerDuQUIQ"
          )

  setup do
    {:ok, zstd} = Zstd.init()
    {:ok, zstd: zstd}
  end

  test "the NIF is loaded in EDA's own test environment" do
    assert Zstd.available?()
  end

  test "decompresses each message of the stream in the same context", %{zstd: zstd} do
    assert {:ok, first, zstd} = Zstd.push(zstd, @frame1)
    assert %{"op" => 10, "d" => %{"heartbeat_interval" => 41_250}} = :erlang.binary_to_term(first)

    assert {:ok, second, _zstd} = Zstd.push(zstd, @frame2)

    assert %{"t" => "MESSAGE_CREATE", "d" => %{"content" => "hello zstd " <> _}} =
             :erlang.binary_to_term(second)
  end

  test "a message that depends on an earlier one fails in a fresh context", %{zstd: zstd} do
    assert {:error, :decompress_failed, _zstd} = Zstd.push(zstd, @frame2)
  end

  test "reset starts a new stream", %{zstd: zstd} do
    {:ok, _, zstd} = Zstd.push(zstd, @frame1)
    zstd = Zstd.reset(zstd)
    assert {:ok, first, _} = Zstd.push(zstd, @frame1)
    assert %{"op" => 10} = :erlang.binary_to_term(first)
  end

  test "corrupt data is an error, and the context recovers", %{zstd: zstd} do
    assert {:error, :decompress_failed, zstd} = Zstd.push(zstd, "not a zstd stream at all")
    assert {:ok, _, _} = Zstd.push(zstd, @frame1)
  end

  test "an empty frame produces nothing yet", %{zstd: zstd} do
    assert {:incomplete, _} = Zstd.push(zstd, <<>>)
  end

  test "a frame split in two still decompresses", %{zstd: zstd} do
    <<a::binary-size(20), b::binary>> = @frame1
    assert {:ok, part, zstd} = Zstd.push(zstd, a) |> then(&normalize/1)
    assert {:ok, rest, _} = Zstd.push(zstd, b)
    assert %{"op" => 10} = :erlang.binary_to_term(part <> rest)
  end

  # A first half may already yield bytes, or none at all.
  defp normalize({:incomplete, zstd}), do: {:ok, <<>>, zstd}
  defp normalize(other), do: other
end
