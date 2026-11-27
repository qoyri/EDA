defmodule EDA.TLS do
  @moduledoc false
  # The TLS options of EDA's WebSocket connections, to the gateway and to voice servers.
  #
  # WebSockex does not verify the server's certificate unless told how: its default is
  # `verify: :verify_none`. The gateway connection carries the bot token in IDENTIFY, and the
  # voice connection the session's token and keys, so both must know who they are talking to.
  #
  # The trust store is the one REST already uses — the CA bundle hackney ships with — so the
  # gateway connects wherever a REST call does, a container without system certificates
  # included. Without that bundle, the operating system's store is used.

  @doc """
  Options for `WebSockex.start_link/4` that make a `wss://` connection verify its peer: the
  certificate chain against the trust store, and the certificate's name against the host.
  They have no effect on a `ws://` URL.
  """
  @spec websocket_options() :: keyword()
  def websocket_options, do: [ssl_options: ssl_options()]

  @doc false
  @spec ssl_options() :: keyword()
  def ssl_options do
    [
      verify: :verify_peer,
      cacerts: cacerts(),
      depth: 10,
      # Without this, OTP matches a wildcard certificate (`*.discord.media`) as a literal name.
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  end

  # Read once: the bundle is a few hundred certificates, and a shard reconnects often enough.
  defp cacerts do
    case :persistent_term.get({__MODULE__, :cacerts}, nil) do
      nil ->
        certs = load_cacerts()
        :persistent_term.put({__MODULE__, :cacerts}, certs)
        certs

      certs ->
        certs
    end
  end

  defp load_cacerts do
    if Code.ensure_loaded?(:certifi) and function_exported?(:certifi, :cacerts, 0) do
      # certifi comes with hackney, not as a dependency of EDA's own: called through apply/3 so
      # the compiler does not expect it.
      apply(:certifi, :cacerts, [])
    else
      :public_key.cacerts_get()
    end
  end
end
