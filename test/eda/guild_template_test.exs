defmodule EDA.GuildTemplateTest do
  use ExUnit.Case, async: true

  alias EDA.GuildTemplate
  alias EDA.GuildTemplate.SourceGuild

  @raw_template %{
    "code" => "hgM48av5Q69A",
    "name" => "My Template",
    "description" => "A cool server template",
    "usage_count" => 12,
    "creator_id" => "123456789",
    "creator" => %{"id" => "123456789", "username" => "creator"},
    "created_at" => "2020-01-01T00:00:00+00:00",
    "updated_at" => "2020-06-01T12:00:00+00:00",
    "source_guild_id" => "987654321",
    "serialized_source_guild" => %{
      "name" => "Template Guild",
      "description" => "Guild description",
      "region" => "",
      "verification_level" => 1,
      "default_message_notifications" => 0,
      "explicit_content_filter" => 2,
      "preferred_locale" => "en-US",
      "afk_timeout" => 300,
      "afk_channel_id" => 2,
      "system_channel_id" => 1,
      "system_channel_flags" => 0,
      "icon_hash" => nil,
      "roles" => [
        %{"id" => 0, "name" => "@everyone", "permissions" => "104324673"},
        %{"id" => 1, "name" => "Moderator", "permissions" => "268435456", "color" => 3_447_003}
      ],
      "channels" => [
        %{"id" => 1, "name" => "general", "type" => 0, "parent_id" => nil, "position" => 0},
        %{"id" => 2, "name" => "Voice", "type" => 2, "parent_id" => nil, "position" => 1}
      ]
    },
    "is_dirty" => false
  }

  describe "from_raw/1" do
    test "parses all fields from a complete template" do
      template = GuildTemplate.from_raw(@raw_template)

      assert %GuildTemplate{} = template
      assert template.code == "hgM48av5Q69A"
      assert template.name == "My Template"
      assert template.description == "A cool server template"
      assert template.usage_count == 12
      assert template.creator_id == "123456789"
      assert %EDA.User{id: "123456789", username: "creator"} = template.creator
      assert template.created_at == ~U[2020-01-01 00:00:00Z]
      assert template.updated_at == ~U[2020-06-01 12:00:00Z]
      assert template.source_guild_id == "987654321"
      assert template.is_dirty == false
    end

    test "parses serialized_source_guild into SourceGuild struct" do
      template = GuildTemplate.from_raw(@raw_template)

      assert %SourceGuild{} = template.serialized_source_guild
      assert template.serialized_source_guild.name == "Template Guild"
    end

    test "handles nil description and is_dirty" do
      raw = %{"code" => "abc", "name" => "Test", "description" => nil, "is_dirty" => nil}
      template = GuildTemplate.from_raw(raw)

      assert template.description == nil
      assert template.is_dirty == nil
    end

    test "handles missing serialized_source_guild" do
      raw = %{"code" => "abc", "name" => "Test"}
      template = GuildTemplate.from_raw(raw)

      assert template.serialized_source_guild == nil
    end
  end

  describe "SourceGuild.from_raw/1" do
    test "parses all fields" do
      raw = @raw_template["serialized_source_guild"]
      sg = SourceGuild.from_raw(raw)

      assert %SourceGuild{} = sg
      assert sg.name == "Template Guild"
      assert sg.description == "Guild description"
      assert sg.region == ""
      assert sg.verification_level == :low
      assert sg.default_message_notifications == :all_messages
      assert sg.explicit_content_filter == :all_members
      assert sg.preferred_locale == "en-US"
      assert sg.afk_timeout == 300
      assert sg.afk_channel_id == 2
      assert sg.system_channel_id == 1
      assert sg.system_channel_flags == 0
      assert sg.icon_hash == nil
    end

    test "reads roles as EDA.Role structs with placeholder integer IDs" do
      sg = SourceGuild.from_raw(@raw_template["serialized_source_guild"])

      assert length(sg.roles) == 2
      [%EDA.Role{} = everyone, moderator] = sg.roles
      assert everyone["id"] == 0
      assert everyone["name"] == "@everyone"
      assert moderator["id"] == 1
      assert moderator["name"] == "Moderator"
      assert moderator["color"] == 3_447_003
    end

    test "reads channels as EDA.Channel structs with placeholder integer IDs" do
      sg = SourceGuild.from_raw(@raw_template["serialized_source_guild"])

      assert length(sg.channels) == 2
      [%EDA.Channel{} = general, voice] = sg.channels
      assert general["id"] == 1
      assert general["name"] == "general"
      assert general.type == :guild_text
      assert voice["id"] == 2
      assert voice["name"] == "Voice"
      assert voice.type == :guild_voice
    end
  end

  describe "constants" do
    test "max_name_length/0 returns 100" do
      assert GuildTemplate.max_name_length() == 100
    end

    test "max_description_length/0 returns 120" do
      assert GuildTemplate.max_description_length() == 120
    end
  end
end
