defmodule EDA.TypedMessagesTest do
  @moduledoc """
  The message calls return structs: listing and paging a channel, pins, forwards, poll voters,
  reaction users, and the messages an interaction sends and edits.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")
    on_exit(fn -> Application.delete_env(:eda, :base_url) end)
    {:ok, bypass: bypass}
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(200, Jason.encode!(body))
  end

  @message %EDA.Message{id: "20", channel_id: "10"}

  test "a channel's messages, one page, streamed, and pinned with their date", %{bypass: bypass} do
    Bypass.stub(bypass, "GET", "/channels/10/messages", fn conn ->
      json(conn, [%{"id" => "2", "channel_id" => "10"}, %{"id" => "1", "channel_id" => "10"}])
    end)

    Bypass.expect_once(bypass, "GET", "/channels/10/messages/pins", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["before"] == "2026-09-23T10:00:00Z"

      json(conn, %{
        "items" => [
          %{"pinned_at" => "2026-09-22T10:00:00+00:00", "message" => %{"id" => "1"}}
        ],
        "has_more" => false
      })
    end)

    assert {:ok, [%EDA.Message{id: "2"}, %EDA.Message{id: "1"}]} =
             EDA.Message.list(%EDA.Channel{id: "10"}, limit: 2)

    assert [%EDA.Message{id: "2"}] = EDA.Message.stream("10", per_page: 2) |> Enum.take(1)

    assert {:ok,
            %{
              items: [%{pinned_at: ~U[2026-09-22 10:00:00Z], message: %EDA.Message{id: "1"}}],
              has_more: false
            }} =
             EDA.Message.pins("10", before: ~U[2026-09-23 10:00:00Z])
  end

  test "forward/2 returns the forward", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/channels/30/messages", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert %{"message_reference" => %{"type" => 1, "message_id" => "20"}} = Jason.decode!(raw)
      json(conn, %{"id" => "31", "message_reference" => %{"type" => 1, "message_id" => "20"}})
    end)

    assert {:ok, %EDA.Message{id: "31", message_reference: %{type: :forward}}} =
             EDA.Message.forward(@message, "30")
  end

  test "poll voters and reaction users are EDA.User structs", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/channels/10/polls/20/answers/1", fn conn ->
      json(conn, %{"users" => [%{"id" => "5", "username" => "ann"}]})
    end)

    Bypass.expect_once(
      bypass,
      "GET",
      "/channels/10/messages/20/reactions/%F0%9F%91%8D",
      fn conn ->
        json(conn, [%{"id" => "6", "username" => "bob"}])
      end
    )

    assert {:ok, [%EDA.User{username: "ann"}]} = EDA.Poll.voters(@message, 1)
    assert {:ok, [%EDA.User{username: "bob"}]} = EDA.Reaction.users(@message, "👍")
  end

  test "an interaction's followup is an EDA.Message, which can be edited and deleted",
       %{bypass: bypass} do
    interaction = %{"application_id" => "app", "token" => "tok", "channel_id" => "10"}

    Bypass.expect_once(bypass, "POST", "/webhooks/app/tok", fn conn ->
      json(conn, %{"id" => "40", "content" => "hi"})
    end)

    Bypass.expect_once(bypass, "PATCH", "/webhooks/app/tok/messages/40", fn conn ->
      json(conn, %{"id" => "40", "content" => "edited"})
    end)

    Bypass.expect_once(bypass, "DELETE", "/webhooks/app/tok/messages/40", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %EDA.Message{id: "40"} = sent} = EDA.Interaction.followup(interaction, "hi")

    assert {:ok, %EDA.Message{content: "edited"}} =
             EDA.Interaction.edit_followup(interaction, sent, "edited")

    assert :ok = EDA.Interaction.delete_followup(interaction, sent)
  end
end
