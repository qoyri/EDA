defmodule EDA.ContentScanTest do
  @moduledoc """
  The flags Discord's content scanning sets on attachments, embeds and component media, and
  the helpers that read them across a whole message.
  """
  use ExUnit.Case, async: true

  import Bitwise

  alias EDA.{Attachment, Embed, Message}
  alias EDA.Component.Media

  doctest EDA.Embed, only: [content_flags: 1, flagged?: 1]
  doctest EDA.Embed.Flags
  doctest EDA.Component.Media
  doctest EDA.Message, only: [content_flags: 1, flagged?: 1]

  describe "attachments" do
    test "the three scanning flags have Discord's bits" do
      assert Attachment.flag_explicit_content() == 1 <<< 4
      assert Attachment.flag_gore_content() == 1 <<< 6
      assert Attachment.flag_self_harm_content() == 1 <<< 7
    end

    test "they are named by flag_list/1 next to the older flags" do
      flags = 1 <<< 3 ||| 1 <<< 4 ||| 1 <<< 5 ||| 1 <<< 7

      assert Attachment.flag_list(%Attachment{flags: flags}) ==
               [:animated, :explicit_content, :self_harm_content, :spoiler]
    end

    test "content_flags/1 reads a struct, a raw map and a bitfield" do
      assert Attachment.content_flags(%Attachment{flags: 1 <<< 6}) == [:gore]

      assert Attachment.content_flags(%{"flags" => 1 <<< 4 ||| 1 <<< 7}) == [
               :explicit,
               :self_harm
             ]

      assert Attachment.content_flags(1 <<< 4) == [:explicit]
      assert Attachment.content_flags(nil) == []
    end

    test "a spoiler or an animated image is not flagged" do
      refute Attachment.flagged?(%Attachment{flags: 1 <<< 3 ||| 1 <<< 5})
      refute Attachment.flagged?(%Attachment{flags: nil})
      assert Attachment.flagged?(%Attachment{flags: 1 <<< 7})
    end
  end

  describe "embeds" do
    test "the scanning flags sit around the content inventory flag" do
      assert Embed.Flags.to_list(1 <<< 4 ||| 1 <<< 5 ||| 1 <<< 6 ||| 1 <<< 7) == [
               :contains_explicit_content,
               :is_content_inventory_entry,
               :contains_gore_content,
               :contains_self_harm_content
             ]
    end

    test "a content inventory entry alone is not flagged" do
      refute Embed.flagged?(%Embed{flags: 1 <<< 5})

      assert Embed.content_flags(Embed.from_raw(%{"type" => "image", "flags" => 1 <<< 4})) ==
               [:explicit]
    end
  end

  describe "component media" do
    test "content_scan_metadata is read into content_scan_flags" do
      media =
        Media.from_raw(%{
          "url" => "https://example.com/a.png",
          "flags" => 0,
          "content_scan_metadata" => %{"flags" => 0b110}
        })

      assert media.content_scan_flags == 0b110
      assert Media.content_flags(media) == [:gore, :self_harm]
      assert Media.flagged?(media)
    end

    test "media not scanned yet has no result, and is not flagged" do
      media = Media.from_raw(%{"url" => "https://example.com/a.png"})

      assert media.content_scan_flags == nil
      refute Media.flagged?(media)
    end

    test "the scan's bits are not the unfurled media item's own flags" do
      # `flags` is another table: bit 0 there says nothing about explicit content.
      refute Media.flagged?(Media.from_raw(%{"url" => "x", "flags" => 1}))
    end
  end

  describe "a whole message" do
    test "reads attachments, embeds, nested components and forwarded messages" do
      message =
        Message.from_raw(%{
          "id" => "1",
          "channel_id" => "2",
          "attachments" => [%{"id" => "3", "flags" => 1 <<< 3}],
          "embeds" => [%{"type" => "image", "flags" => 1 <<< 6}],
          "components" => [
            %{
              "type" => 17,
              "components" => [
                %{
                  "type" => 9,
                  "components" => [%{"type" => 10, "content" => "hi"}],
                  "accessory" => %{
                    "type" => 11,
                    "media" => %{"url" => "u", "content_scan_metadata" => %{"flags" => 1}}
                  }
                }
              ]
            }
          ],
          "message_snapshots" => [
            %{"message" => %{"attachments" => [%{"id" => "4", "flags" => 1 <<< 7}]}}
          ]
        })

      assert Message.content_flags(message) == [:explicit, :gore, :self_harm]
      assert Message.flagged?(message)
    end

    test "reads a media gallery and a file component" do
      message =
        Message.from_raw(%{
          "id" => "1",
          "channel_id" => "2",
          "components" => [
            %{
              "type" => 12,
              "items" => [
                %{"media" => %{"url" => "a"}},
                %{"media" => %{"url" => "b", "content_scan_metadata" => %{"flags" => 2}}}
              ]
            },
            %{
              "type" => 13,
              "file" => %{"url" => "c", "content_scan_metadata" => %{"flags" => 4}}
            }
          ]
        })

      assert Message.content_flags(message) == [:gore, :self_harm]
    end

    test "reads the media of a components embed" do
      message =
        Message.from_raw(%{
          "id" => "1",
          "channel_id" => "2",
          "embeds" => [
            %{
              "type" => "components",
              "components" => [
                %{
                  "type" => 17,
                  "components" => [
                    %{
                      "type" => 12,
                      "items" => [
                        %{"media" => %{"url" => "a", "content_scan_metadata" => %{"flags" => 1}}}
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        })

      assert Message.content_flags(message) == [:explicit]
    end

    test "a message with nothing flagged, or nothing at all" do
      refute Message.flagged?(%Message{})

      refute Message.flagged?(
               Message.from_raw(%{
                 "id" => "1",
                 "channel_id" => "2",
                 "attachments" => [%{"id" => "3", "flags" => 0}],
                 "embeds" => [%{"type" => "rich", "title" => "t"}]
               })
             )
    end
  end
end
