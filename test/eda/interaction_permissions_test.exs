defmodule EDA.InteractionPermissionsTest do
  @moduledoc """
  Covers the permissions Discord ships with an interaction.

  Two things make this worth its own file. The bitsets arrive as **strings**, because they
  exceed 53 bits and would lose precision as JSON numbers — so anything that forgets to
  parse them silently compares a binary against an integer and is always false. And a
  resolved channel carries *two* bitsets: `app_permissions` for the bot and `permissions`
  for the invoking user. Mixing them up produces a check that passes for the wrong party.
  """

  use ExUnit.Case, async: true

  import Bitwise

  alias EDA.Interaction
  alias EDA.Permission

  @send_messages Permission.to_bitset([:send_messages])
  @embed_links Permission.to_bitset([:embed_links])
  @manage_messages Permission.to_bitset([:manage_messages])

  defp interaction(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "i1",
        "type" => 2,
        "app_permissions" => to_string(@send_messages ||| @embed_links),
        "data" => %{
          "name" => "post",
          "resolved" => %{
            "channels" => %{
              "c_allowed" => %{
                "id" => "c_allowed",
                "name" => "general",
                "type" => 0,
                "app_permissions" => to_string(@send_messages),
                "permissions" => to_string(@send_messages ||| @manage_messages)
              },
              "c_denied" => %{
                "id" => "c_denied",
                "name" => "locked",
                "type" => 0,
                "app_permissions" => "0",
                "permissions" => "0"
              }
            }
          }
        }
      },
      overrides
    )
  end

  describe "app_permissions/1 — the interaction's own channel" do
    test "parses the string bitset Discord sends" do
      assert Interaction.app_permissions(interaction()) == (@send_messages ||| @embed_links)
    end

    test "reads an atom-keyed struct as well as a raw map" do
      struct = EDA.Event.InteractionCreate.from_raw(interaction())

      assert Interaction.app_permissions(struct) == (@send_messages ||| @embed_links)
    end

    test "absent is nil, not zero — not being told is not the same as being denied" do
      assert Interaction.app_permissions(%{"id" => "i1"}) == nil
      assert Interaction.app_permissions(interaction(%{"app_permissions" => nil})) == nil
    end

    test "a value that is not a bitset is nil rather than a crash" do
      assert Interaction.app_permissions(interaction(%{"app_permissions" => "not a number"})) ==
               nil

      assert Interaction.app_permissions(interaction(%{"app_permissions" => "12abc"})) == nil
    end

    test "an integer is accepted too, for anyone who parsed it already" do
      assert Interaction.app_permissions(interaction(%{"app_permissions" => 2048})) == 2048
    end
  end

  describe "app_permissions/2 — a resolved channel" do
    test "is the bot's permissions in that channel, not in the interaction's" do
      # The interaction channel allows embed_links; the resolved one does not.
      assert Interaction.app_permissions(interaction(), "c_allowed") == @send_messages

      refute Interaction.app_permissions(interaction(), "c_allowed") ==
               Interaction.app_permissions(interaction())
    end

    test "a channel with nothing granted is 0, which is different from nil" do
      assert Interaction.app_permissions(interaction(), "c_denied") == 0
    end

    test "a channel that was not resolved is nil" do
      assert Interaction.app_permissions(interaction(), "c_unknown") == nil
    end
  end

  describe "user_permissions/1 — the interaction's own channel" do
    test "reads the member's precomputed bitset" do
      payload =
        interaction(%{
          "member" => %{
            "user" => %{"id" => "u1"},
            "permissions" => to_string(@send_messages ||| @manage_messages)
          }
        })

      assert Interaction.user_permissions(payload) == (@send_messages ||| @manage_messages)
      assert Interaction.user_can?(payload, :manage_messages)
      refute Interaction.user_can?(payload, :embed_links)
    end

    test "works through the parsed struct too" do
      payload =
        interaction(%{
          "member" => %{"user" => %{"id" => "u1"}, "permissions" => to_string(@manage_messages)}
        })

      struct = EDA.Event.InteractionCreate.from_raw(payload)

      assert struct.member.permissions == to_string(@manage_messages)
      assert Interaction.user_permissions(struct) == @manage_messages
      assert Interaction.user_can?(struct, :manage_messages)
    end

    test "nil outside a guild, where there is no member" do
      assert Interaction.user_permissions(interaction()) == nil
      assert Interaction.user_permissions(%{"id" => "i1"}) == nil
      refute Interaction.user_can?(%{"id" => "i1"}, :send_messages)
    end

    test "the bot's and the user's bitsets are different questions" do
      payload =
        interaction(%{
          "member" => %{"user" => %{"id" => "u1"}, "permissions" => to_string(@manage_messages)}
        })

      assert Interaction.app_permissions(payload) == (@send_messages ||| @embed_links)
      assert Interaction.user_permissions(payload) == @manage_messages
    end
  end

  describe "user_permissions/2" do
    test "is the invoking user's permissions, not the bot's" do
      assert Interaction.user_permissions(interaction(), "c_allowed") ==
               (@send_messages ||| @manage_messages)

      assert Interaction.app_permissions(interaction(), "c_allowed") == @send_messages
    end

    test "nil for a channel that was not resolved" do
      assert Interaction.user_permissions(interaction(), "c_unknown") == nil
    end
  end

  describe "can?/2 and can?/3" do
    test "asks about the interaction's channel with two arguments" do
      assert Interaction.can?(interaction(), :send_messages)
      assert Interaction.can?(interaction(), :embed_links)
      refute Interaction.can?(interaction(), :manage_messages)
    end

    test "asks about a resolved channel with three" do
      assert Interaction.can?(interaction(), "c_allowed", :send_messages)
      # granted where the command was typed, not where it would post
      refute Interaction.can?(interaction(), "c_allowed", :embed_links)
      refute Interaction.can?(interaction(), "c_denied", :send_messages)
    end

    test "an unknown channel is false — not being told is not permission" do
      refute Interaction.can?(interaction(), "c_unknown", :send_messages)
    end

    test "an interaction with no app_permissions at all is false" do
      refute Interaction.can?(%{"id" => "i1"}, :send_messages)
    end
  end

  describe "user_can?/3" do
    test "reads the user's bitset, so it can differ from the bot's" do
      assert Interaction.user_can?(interaction(), "c_allowed", :manage_messages)
      refute Interaction.can?(interaction(), "c_allowed", :manage_messages)
    end

    test "false for a channel that was not resolved" do
      refute Interaction.user_can?(interaction(), "c_unknown", :send_messages)
    end
  end

  describe "permission_list/1,2" do
    test "names what the bot holds where the interaction happened" do
      names = Interaction.permission_list(interaction())

      assert :send_messages in names
      assert :embed_links in names
    end

    test "names what it holds in a resolved channel" do
      assert Interaction.permission_list(interaction(), "c_allowed") == [:send_messages]
      assert Interaction.permission_list(interaction(), "c_denied") == []
    end

    test "an absent bitset lists nothing rather than raising" do
      assert Interaction.permission_list(%{"id" => "i1"}) == []
      assert Interaction.permission_list(interaction(), "c_unknown") == []
    end
  end

  describe "resolved_channel/2 and resolved_channels/1" do
    test "returns a struct carrying the partial fields Discord sent" do
      channel = Interaction.resolved_channel(interaction(), "c_allowed")

      assert %EDA.Channel{} = channel
      assert channel.id == "c_allowed"
      assert channel.name == "general"
      assert channel.type == 0
      assert channel.app_permissions == to_string(@send_messages)
      assert channel.permissions == to_string(@send_messages ||| @manage_messages)
    end

    test "fields Discord omits from a partial channel are nil, not missing" do
      channel = Interaction.resolved_channel(interaction(), "c_allowed")

      assert channel.topic == nil
      assert channel.permission_overwrites == nil
    end

    test "nil for a channel that was not resolved" do
      assert Interaction.resolved_channel(interaction(), "c_unknown") == nil
    end

    test "lists every resolved channel" do
      ids = interaction() |> Interaction.resolved_channels() |> Enum.map(& &1.id) |> Enum.sort()

      assert ids == ["c_allowed", "c_denied"]
    end

    test "an interaction with no resolved data lists nothing" do
      assert Interaction.resolved_channels(%{"id" => "i1"}) == []
      assert Interaction.resolved_channels(%{"data" => %{"name" => "ping"}}) == []
    end
  end
end
