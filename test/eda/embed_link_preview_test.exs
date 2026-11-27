defmodule EDA.EmbedLinkPreviewTest do
  @moduledoc "The embeds Discord makes for a link: an audio file, a site's own component layout."
  use ExUnit.Case, async: true

  alias EDA.Embed

  test "an audio embed carries the file in `audio`" do
    embed =
      Embed.from_raw(%{
        "type" => "audio",
        "url" => "https://example.com/a.mp3",
        "audio" => %{
          "url" => "https://example.com/a.mp3",
          "proxy_url" => "https://media.example/a.mp3",
          "content_type" => "audio/mpeg",
          "description" => "A jingle"
        }
      })

    assert embed.type == :audio
    assert %Embed.Media{content_type: "audio/mpeg", description: "A jingle"} = embed.audio
    assert embed.audio.proxy_url == "https://media.example/a.mp3"
    assert embed["audio"]["description"] == "A jingle"
  end

  test "an image or a video keeps its alt text" do
    embed =
      Embed.from_raw(%{
        "type" => "image",
        "image" => %{"url" => "https://example.com/a.png", "description" => "A cat"},
        "video" => %{"url" => "https://example.com/a.mp4", "description" => "A dog"}
      })

    assert embed.image.description == "A cat"
    assert embed.video.description == "A dog"
  end

  test "a components embed holds its container, parsed like a message's components" do
    embed =
      Embed.from_raw(%{
        "type" => "components",
        "url" => "https://example.com/patch-notes",
        "components" => [
          %{
            "type" => 17,
            "accent_color" => 5_793_266,
            "components" => [
              %{"type" => 10, "content" => "# Patch Notes"},
              %{
                "type" => 1,
                "components" => [
                  %{"type" => 2, "style" => 5, "label" => "Read", "url" => "https://example.com"}
                ]
              }
            ]
          }
        ]
      })

    assert embed.type == :components

    assert [%EDA.Component.Container{accent_color: 5_793_266, components: [text, row]}] =
             embed.components

    assert %EDA.Component.TextDisplay{content: "# Patch Notes"} = text
    assert %EDA.Component.ActionRow{components: [%EDA.Component.Button{style: :link}]} = row
  end

  test "an ordinary embed has neither" do
    embed = Embed.from_raw(%{"type" => "rich", "title" => "Hi"})

    assert embed.audio == nil
    assert embed.components == nil
  end

  test "what only Discord sets is left out when the embed is sent again" do
    sent =
      %{
        "type" => "audio",
        "title" => "Song",
        "audio" => %{"url" => "https://example.com/a.mp3"},
        "components" => [%{"type" => 17, "components" => []}],
        "flags" => 16
      }
      |> Embed.from_raw()
      |> Embed.to_map()

    assert sent == %{title: "Song"}
  end

  test "a type Discord adds later stays its string" do
    assert Embed.from_raw(%{"type" => "hologram"}).type == "hologram"
  end
end
