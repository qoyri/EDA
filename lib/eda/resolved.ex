defmodule EDA.Resolved do
  @moduledoc """
  The users, members, roles, channels, messages and attachments a message's components or an
  interaction refer to by id, each a map from id to struct.

  Discord sends a resolved member without its user, which it lists apart in `users`; EDA puts
  the user back on the member, so `resolved.members[id].user` is set.

      resolved.users["80351110224678912"].username
  """

  use EDA.Event.Access

  defstruct users: %{}, members: %{}, roles: %{}, channels: %{}, messages: %{}, attachments: %{}

  @type t :: %__MODULE__{
          users: %{String.t() => EDA.User.t()},
          members: %{String.t() => EDA.Member.t()},
          roles: %{String.t() => EDA.Role.t()},
          channels: %{String.t() => EDA.Channel.t()},
          messages: %{String.t() => EDA.Message.t()},
          attachments: %{String.t() => EDA.Attachment.t()}
        }

  @doc """
  Resolved data as Discord sends it.

      iex> resolved = EDA.Resolved.from_raw(%{
      ...>   "users" => %{"1" => %{"id" => "1", "username" => "ann"}},
      ...>   "members" => %{"1" => %{"nick" => "Annie"}}
      ...> })
      iex> {resolved.members["1"].nick, resolved.members["1"].user.username}
      {"Annie", "ann"}
  """
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    users = parse(raw["users"], &EDA.User.from_raw/1)

    %__MODULE__{
      users: users,
      members:
        Map.new(raw["members"] || %{}, fn {id, member} ->
          {id, %{EDA.Member.from_raw(member) | user: users[id]}}
        end),
      roles: parse(raw["roles"], &EDA.Role.from_raw/1),
      channels: parse(raw["channels"], &EDA.Channel.from_raw/1),
      messages: parse(raw["messages"], &EDA.Message.from_raw/1),
      attachments: parse(raw["attachments"], &EDA.Attachment.from_raw/1)
    }
  end

  defp parse(nil, _from_raw), do: %{}
  defp parse(by_id, from_raw), do: Map.new(by_id, fn {id, raw} -> {id, from_raw.(raw)} end)
end
