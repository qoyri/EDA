defmodule EDA.Event.AccessTest do
  @moduledoc """
  The access contract: every struct built from Discord data answers `x.field`, `x[:field]` and
  `x["field"]`, nested ones included.

  Nine structs used to lack it, so `reaction.emoji["name"]` raised `UndefinedFunctionError` on a
  struct nested in every reaction event. The first test walks every module instead of listing
  them, so a struct added without the contract fails here.
  """

  use ExUnit.Case, async: true

  alias EDA.Event.MessageCreate

  defp sample_msg do
    MessageCreate.from_raw(%{
      "id" => "123",
      "channel_id" => "456",
      "content" => "hello world",
      "author" => %{"id" => "789", "username" => "testuser"}
    })
  end

  describe "fetch/2" do
    test "atom key access works" do
      msg = sample_msg()
      assert {:ok, "hello world"} = Access.fetch(msg, :content)
    end

    test "string key access works" do
      msg = sample_msg()
      assert {:ok, "hello world"} = Access.fetch(msg, "content")
    end

    test "string key returns :error for nonexistent field" do
      msg = sample_msg()
      assert :error = Access.fetch(msg, "nonexistent_field_xyz")
    end

    test "atom key returns :error for nonexistent field" do
      msg = sample_msg()
      assert :error = Access.fetch(msg, :nonexistent_field_xyz)
    end
  end

  describe "bracket access" do
    test "struct[:field] works" do
      msg = sample_msg()
      assert msg[:content] == "hello world"
    end

    test "struct[\"field\"] works" do
      msg = sample_msg()
      assert msg["content"] == "hello world"
    end

    test "nil for missing string key" do
      msg = sample_msg()
      assert msg["no_such_key_xyz"] == nil
    end
  end

  describe "dot access" do
    test "struct.field works" do
      msg = sample_msg()
      assert msg.content == "hello world"
      assert msg.id == "123"
    end
  end

  describe "get_in/2" do
    test "works with atom keys" do
      msg = sample_msg()
      assert get_in(msg, [:content]) == "hello world"
    end

    test "works with string keys" do
      msg = sample_msg()
      assert get_in(msg, ["content"]) == "hello world"
    end

    test "works with mixed keys into nested structs" do
      msg = sample_msg()
      assert get_in(msg, [:author]) == %EDA.User{id: "789", username: "testuser"}
    end
  end

  describe "get_and_update/3" do
    test "works with atom key" do
      msg = sample_msg()

      {old, updated} =
        Access.get_and_update(msg, :content, fn val -> {val, "updated"} end)

      assert old == "hello world"
      assert updated.content == "updated"
    end

    test "works with string key" do
      msg = sample_msg()

      {old, updated} =
        Access.get_and_update(msg, "content", fn val -> {val, "updated"} end)

      assert old == "hello world"
      assert updated.content == "updated"
    end
  end

  describe "pop/2" do
    test "works with atom key" do
      msg = sample_msg()
      {val, rest} = Access.pop(msg, :content)
      assert val == "hello world"
      assert rest[:content] == nil
    end

    test "works with string key" do
      msg = sample_msg()
      {val, rest} = Access.pop(msg, "content")
      assert val == "hello world"
      assert rest[:content] == nil
    end
  end

  defp data_structs do
    {:ok, modules} = :application.get_key(:eda, :modules)

    for mod <- modules,
        Code.ensure_loaded?(mod),
        function_exported?(mod, :__struct__, 0),
        function_exported?(mod, :from_raw, 1),
        do: mod
  end

  test "every struct built from Discord data implements the contract" do
    missing = Enum.reject(data_structs(), &function_exported?(&1, :fetch, 2))
    assert missing == [], "without EDA.Event.Access: #{inspect(missing)}"
  end

  test "an emoji nested in a reaction event is reachable by string key" do
    event =
      EDA.Event.from_raw("MESSAGE_REACTION_ADD", %{
        "user_id" => "1",
        "channel_id" => "2",
        "message_id" => "3",
        "emoji" => %{"id" => "4", "name" => "blob"}
      })

    assert event["emoji"]["name"] == "blob"
    assert get_in(event, ["emoji", "name"]) == "blob"
    assert event.emoji[:name] == "blob"
  end

  test "the other structs that lacked it" do
    assert EDA.Sticker.from_raw(%{"id" => "1", "name" => "s"})["name"] == "s"
    assert EDA.AutoMod.from_raw(%{"id" => "1", "name" => "rule"})["name"] == "rule"
    assert EDA.GuildTemplate.from_raw(%{"code" => "abc"})["code"] == "abc"
  end

  describe "string keys" do
    setup do
      %{user: EDA.User.from_raw(%{"id" => "1", "username" => "someone"})}
    end

    test "read a field like the atom key does", %{user: user} do
      assert user["username"] == "someone"
      assert user[:username] == "someone"
      assert Access.fetch(user, "username") == {:ok, "someone"}
    end

    test "a key that is not a field answers nil, even a string never seen as an atom",
         %{user: user} do
      assert user["not_a_field"] == nil
      assert user["zzz_#{System.unique_integer([:positive])}"] == nil
      assert Access.fetch(user, "not_a_field") == :error
    end
  end

  describe "writing through the contract keeps a valid struct" do
    setup do
      %{user: EDA.User.from_raw(%{"id" => "1", "username" => "someone"})}
    end

    test "put_in on a field, by string or atom", %{user: user} do
      assert %EDA.User{username: "other"} = put_in(user["username"], "other")
      assert %EDA.User{username: "other"} = put_in(user[:username], "other")
    end

    test "put_in on a key the struct does not have raises instead of adding it", %{user: user} do
      assert_raise KeyError, fn -> put_in(user["not_a_field"], 1) end
      assert_raise KeyError, fn -> put_in(user[:not_a_field], 1) end
    end

    test "pop_in resets a field to nil rather than removing it", %{user: user} do
      assert {"someone", %EDA.User{username: nil} = popped} = pop_in(user["username"])
      assert Map.has_key?(popped, :username)
      assert {nil, ^user} = pop_in(user["not_a_field"])
    end
  end
end
