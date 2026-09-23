defmodule EDA.MediumHelpersTest do
  @moduledoc """
  Channel kinds and links, attachment kinds, voice states, activity times and images, emoji
  parsing, webhook URLs and audit log changes.
  """

  # NOT async — children/1 reads the shared channel cache.
  use ExUnit.Case

  doctest EDA.Channel, only: [text?: 1, url: 1]
  doctest EDA.Attachment, only: [image?: 1, extension: 1]
  doctest EDA.Activity, only: [large_image_url: 1]
  doctest EDA.Emoji, only: [parse: 1]
  doctest EDA.Webhook, only: [url: 1]
  doctest EDA.AuditLog.Entry, only: [change: 2]

  test "channel kinds, and a thread's state" do
    assert EDA.Channel.voice?(%EDA.Channel{type: :guild_stage_voice})
    assert EDA.Channel.category?(%EDA.Channel{type: :guild_category})
    assert EDA.Channel.dm?(%EDA.Channel{type: :dm})
    refute EDA.Channel.text?(%EDA.Channel{type: :guild_voice})

    thread =
      EDA.Channel.from_raw(%{
        "type" => 11,
        "thread_metadata" => %{"archived" => true, "locked" => true}
      })

    assert EDA.Channel.archived?(thread) and EDA.Channel.locked?(thread)
    refute EDA.Channel.archived?(%EDA.Channel{type: :guild_text})
  end

  test "a category's children, by position" do
    guild = "7716000000000000000"
    category = "7716000000000000001"

    for {id, position} <- [{"7716000000000000003", 2}, {"7716000000000000002", 1}] do
      EDA.Cache.Channel.create(%{
        "id" => id,
        "guild_id" => guild,
        "parent_id" => category,
        "type" => 0,
        "position" => position
      })
    end

    assert ["7716000000000000002", "7716000000000000003"] =
             %EDA.Channel{id: category, guild_id: guild}
             |> EDA.Channel.children()
             |> Enum.map(& &1.id)
  end

  test "attachment kinds come from the content type first" do
    assert EDA.Attachment.video?(%EDA.Attachment{content_type: "video/mp4", filename: "x.bin"})
    assert EDA.Attachment.audio?(%EDA.Attachment{filename: "voice-message.ogg"})
    refute EDA.Attachment.image?(%EDA.Attachment{filename: "notes"})
  end

  test "a voice state's mute and deafness, whoever set them" do
    assert EDA.VoiceState.muted?(%EDA.VoiceState{self_mute: true})
    assert EDA.VoiceState.muted?(%EDA.VoiceState{suppress: true})
    assert EDA.VoiceState.deafened?(%EDA.VoiceState{deaf: true})
    refute EDA.VoiceState.deafened?(%EDA.VoiceState{mute: true})
  end

  test "an activity's elapsed and remaining time" do
    now = ~U[2026-09-23 10:00:00Z]

    activity = %EDA.Activity{
      timestamps: %EDA.Activity.Timestamps{
        start: ~U[2026-09-23 09:58:00Z],
        end: ~U[2026-09-23 10:01:30Z]
      }
    }

    assert EDA.Activity.elapsed(activity, now) == 120
    assert EDA.Activity.remaining(activity, now) == 90
    assert EDA.Activity.elapsed(%EDA.Activity{}, now) == nil

    assert EDA.Activity.small_image_url(%EDA.Activity{
             assets: %EDA.Activity.Assets{small_image: "mp:external/abc/x.png"}
           }) ==
             "https://media.discordapp.net/external/abc/x.png"
  end
end
