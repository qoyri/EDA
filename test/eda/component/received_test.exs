defmodule EDA.Component.ReceivedTest do
  @moduledoc """
  The components of a received message, read into structs and sent back as Discord takes them.
  """

  use ExUnit.Case, async: true

  alias EDA.Component

  alias EDA.Component.{
    ActionRow,
    Button,
    Container,
    File,
    Media,
    MediaGallery,
    SelectMenu,
    SelectOption,
    Section,
    Separator,
    TextDisplay,
    Thumbnail
  }

  doctest EDA.Component, only: [from_raw: 1, to_raw: 1]

  # Shaped like a real components v2 message: the keys are those captured on the test server.
  @media %{
    "id" => "1419000000000000000",
    "url" => "https://cdn.discordapp.com/attachments/1/2/cat.png",
    "proxy_url" => "https://media.discordapp.net/attachments/1/2/cat.png",
    "width" => 640,
    "height" => 480,
    "content_type" => "image/png",
    "placeholder" => "3PcNFYSWh4iAeGd4d4iHeIeHeFCHeHAH",
    "placeholder_version" => 1,
    "loading_state" => 2,
    "flags" => 0
  }

  @container %{
    "type" => 17,
    "id" => 1,
    "accent_color" => 5_793_266,
    "spoiler" => false,
    "components" => [
      %{"type" => 10, "id" => 2, "content" => "# Welcome"},
      %{
        "type" => 9,
        "id" => 3,
        "components" => [%{"type" => 10, "id" => 4, "content" => "A cat"}],
        "accessory" => %{"type" => 11, "id" => 5, "media" => @media, "spoiler" => false}
      },
      %{"type" => 14, "id" => 6, "divider" => true, "spacing" => 2},
      %{
        "type" => 12,
        "id" => 7,
        "items" => [%{"media" => @media, "description" => "a cat", "spoiler" => true}]
      },
      %{"type" => 13, "id" => 8, "file" => %{"url" => "attachment://a.txt"}, "name" => "a.txt"},
      %{
        "type" => 1,
        "id" => 9,
        "components" => [
          %{
            "type" => 2,
            "id" => 10,
            "style" => 5,
            "label" => "Docs",
            "url" => "https://example.com",
            "emoji" => %{"id" => nil, "name" => "📚"}
          },
          %{"type" => 2, "id" => 11, "style" => 1, "label" => "Go", "custom_id" => "go"}
        ]
      },
      %{
        "type" => 1,
        "id" => 12,
        "components" => [
          %{
            "type" => 3,
            "id" => 13,
            "custom_id" => "color",
            "placeholder" => "Pick one",
            "min_values" => 1,
            "max_values" => 1,
            "options" => [%{"label" => "Red", "value" => "red", "description" => "warm"}]
          }
        ]
      }
    ]
  }

  test "a message's components are read down to the leaves" do
    message = EDA.Message.from_raw(%{"id" => "1", "components" => [@container]})

    assert [%Container{id: 1, accent_color: 5_793_266, components: children}] =
             message.components

    assert [
             %TextDisplay{content: "# Welcome"},
             %Section{
               components: [%TextDisplay{content: "A cat"}],
               accessory: %Thumbnail{media: %Media{width: 640, content_type: "image/png"}}
             },
             %Separator{divider: true, spacing: :large},
             %MediaGallery{items: [%MediaGallery.Item{description: "a cat", spoiler: true}]},
             %File{name: "a.txt", file: %Media{url: "attachment://a.txt"}},
             %ActionRow{components: [link, go]},
             %ActionRow{components: [select]}
           ] = children

    assert %Button{style: :link, url: "https://example.com", emoji: %EDA.Emoji{name: "📚"}} =
             link

    assert %Button{style: :primary, custom_id: "go", disabled: false} = go

    assert %SelectMenu{
             type: :string_select,
             custom_id: "color",
             options: [%SelectOption{label: "Red", value: "red", default: false}]
           } = select

    assert go[:custom_id] == "go" and go["label"] == "Go"
  end

  test "auto-filled selects keep their kind, channel types and default values as atoms" do
    select =
      Component.from_raw(%{
        "type" => 8,
        "custom_id" => "where",
        "channel_types" => [0, 2],
        "default_values" => [%{"id" => "42", "type" => "channel"}]
      })

    assert %SelectMenu{
             type: :channel_select,
             channel_types: [:guild_text, :guild_voice],
             default_values: [{:channel, "42"}]
           } = select

    assert Component.to_raw(select) == %{
             type: 8,
             custom_id: "where",
             channel_types: [0, 2],
             default_values: [%{id: "42", type: "channel"}],
             disabled: false
           }
  end

  test "a received message's components are sent back as Discord takes them" do
    [container] = EDA.Message.from_raw(%{"components" => [@container]}).components
    sent = container |> Jason.encode!() |> Jason.decode!()

    assert sent["type"] == 17 and sent["accent_color"] == 5_793_266
    [text, section, separator, gallery, file, links, selects] = sent["components"]

    assert text == %{"type" => 10, "id" => 2, "content" => "# Welcome"}
    assert section["accessory"]["media"] == %{"url" => @media["url"]}
    assert separator == %{"type" => 14, "id" => 6, "divider" => true, "spacing" => 2}
    assert [%{"media" => %{"url" => _}, "spoiler" => true}] = gallery["items"]
    assert file["file"] == %{"url" => "attachment://a.txt"}

    assert [%{"style" => 5, "emoji" => %{"name" => "📚"}}, %{"style" => 1, "custom_id" => "go"}] =
             links["components"]

    assert [%{"type" => 3, "options" => [%{"label" => "Red", "value" => "red"}]}] =
             selects["components"]
  end

  test "disable_all/1 disables the buttons and selects of a received message, accessories too" do
    section =
      Component.from_raw(%{
        "type" => 9,
        "components" => [],
        "accessory" => %{"type" => 2, "style" => 1, "custom_id" => "a"}
      })

    [container] = EDA.Message.from_raw(%{"components" => [@container]}).components

    [%Container{components: children}, %Section{accessory: accessory}] =
      Component.disable_all([container, section])

    assert accessory.disabled

    for %ActionRow{components: row} <- children, component <- row do
      assert component.disabled
    end

    built = %{type: 9, components: [], accessory: Component.button("x", custom_id: "x")}
    assert [%{accessory: %{disabled: true}}] = Component.disable_all([built])
  end

  test "a component kind EDA does not know yet stays the raw map" do
    raw = %{"type" => 99, "id" => 1, "whatever" => true}

    assert [%ActionRow{components: [^raw]}] =
             EDA.Message.from_raw(%{"components" => [%{"type" => 1, "components" => [raw]}]}).components
  end
end
