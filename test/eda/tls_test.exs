defmodule EDA.TLSTest do
  use ExUnit.Case, async: true

  test "a WebSocket connection verifies its peer" do
    ssl = EDA.TLS.websocket_options()[:ssl_options]

    assert ssl[:verify] == :verify_peer
    assert [_ | _] = ssl[:cacerts]
    assert is_function(ssl[:customize_hostname_check][:match_fun], 2)
  end

  test "the options reach WebSockex, which would otherwise not verify at all" do
    conn = WebSockex.Conn.new("wss://gateway.discord.gg/", EDA.TLS.websocket_options())

    assert conn.conn_mod == :ssl
    assert conn.ssl_options[:verify] == :verify_peer
    # The default this guards against.
    assert WebSockex.Conn.new("wss://gateway.discord.gg/").insecure == true
  end

  test "a wildcard certificate matches one label, as for HTTPS" do
    match = EDA.TLS.ssl_options()[:customize_hostname_check][:match_fun]

    assert match.({:dns_id, ~c"c-fra01.discord.media"}, {:dNSName, ~c"*.discord.media"})
    refute match.({:dns_id, ~c"a.b.discord.media"}, {:dNSName, ~c"*.discord.media"})
    refute match.({:dns_id, ~c"discord.media.example"}, {:dNSName, ~c"*.discord.media"})
  end
end
