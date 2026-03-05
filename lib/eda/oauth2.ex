defmodule EDA.OAuth2 do
  @moduledoc """
  OAuth2 helpers for Discord bot applications.
  """

  @base_url "https://discord.com/oauth2/authorize"

  @doc """
  Generates a bot invite URL with the specified permissions and scopes.

  The `client_id` is fetched from the cached bot user (`EDA.Cache.me()["id"]`)
  if not provided.

  ## Options

    * `:client_id` — application/bot client ID (auto-detected if omitted)
    * `:permissions` — list of permission atoms (e.g., `[:send_messages, :manage_messages]`)
      or an integer bitfield (default: `0`)
    * `:scopes` — list of OAuth2 scope strings (default: `["bot", "applications.commands"]`)
    * `:guild_id` — pre-select a guild in the authorization prompt
    * `:disable_guild_select` — if `true`, prevent the user from changing the guild

  ## Examples

      EDA.OAuth2.invite_url()
      #=> "https://discord.com/oauth2/authorize?client_id=123&scope=bot+applications.commands&permissions=0"

      EDA.OAuth2.invite_url(permissions: [:send_messages, :read_message_history])
      #=> "https://discord.com/oauth2/authorize?client_id=123&scope=bot+applications.commands&permissions=65600"

      EDA.OAuth2.invite_url(client_id: "999", guild_id: "555", scopes: ["bot"])
      #=> "https://discord.com/oauth2/authorize?client_id=999&scope=bot&permissions=0&guild_id=555"
  """
  @spec invite_url(keyword()) :: String.t()
  def invite_url(opts \\ []) do
    client_id = Keyword.get_lazy(opts, :client_id, &resolve_client_id/0)
    scopes = Keyword.get(opts, :scopes, ["bot", "applications.commands"])
    permissions = resolve_permissions(Keyword.get(opts, :permissions, 0))

    params = [
      {"client_id", client_id},
      {"scope", Enum.join(scopes, "+")},
      {"permissions", to_string(permissions)}
    ]

    params =
      case Keyword.get(opts, :guild_id) do
        nil -> params
        gid -> params ++ [{"guild_id", to_string(gid)}]
      end

    params =
      if Keyword.get(opts, :disable_guild_select, false) do
        params ++ [{"disable_guild_select", "true"}]
      else
        params
      end

    query = Enum.map_join(params, "&", fn {k, v} -> "#{k}=#{v}" end)
    "#{@base_url}?#{query}"
  end

  defp resolve_client_id do
    case EDA.Cache.me() do
      %{"id" => id} -> id
      _ -> raise "No client_id provided and bot user not cached. Pass :client_id explicitly."
    end
  end

  defp resolve_permissions(perms) when is_integer(perms), do: perms
  defp resolve_permissions(perms) when is_list(perms), do: EDA.Permission.to_bitset(perms)
end
