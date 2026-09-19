defmodule EDA.MessageTest do
  use ExUnit.Case

  alias EDA.Message

  describe "from_raw/1" do
    test "parses nested author, member, mentions, attachments" do
      raw = %{
        "id" => "msg1",
        "channel_id" => "ch1",
        "author" => %{"id" => "u1", "username" => "alice"},
        "content" => "hello",
        "member" => %{"nick" => "ali", "roles" => ["r1"]},
        "mentions" => [%{"id" => "u2", "username" => "bob"}],
        "attachments" => [%{"id" => "a1", "filename" => "f.png"}]
      }

      msg = Message.from_raw(raw)
      assert %Message{} = msg
      assert %EDA.User{id: "u1"} = msg.author
      assert %EDA.Member{nick: "ali"} = msg.member
      assert [%EDA.User{id: "u2"}] = msg.mentions
      assert [%EDA.Attachment{id: "a1"}] = msg.attachments
    end

    test "parses reactions" do
      raw = %{
        "id" => "msg1",
        "reactions" => [%{"count" => 3, "emoji" => %{"name" => "fire"}}]
      }

      msg = Message.from_raw(raw)
      assert [%EDA.Reaction{count: 3}] = msg.reactions
    end

    test "parses recursive referenced_message" do
      raw = %{
        "id" => "msg2",
        "referenced_message" => %{
          "id" => "msg1",
          "author" => %{"id" => "u1", "username" => "alice"},
          "content" => "original"
        }
      }

      msg = Message.from_raw(raw)
      assert %Message{id: "msg1"} = msg.referenced_message
      assert %EDA.User{id: "u1"} = msg.referenced_message.author
    end

    test "handles all nil nested fields" do
      msg = Message.from_raw(%{"id" => "msg1"})
      assert msg.author == nil
      assert msg.member == nil
      assert msg.mentions == nil
      assert msg.attachments == nil
      assert msg.reactions == nil
      assert msg.referenced_message == nil
      assert msg.poll == nil
    end

    test "parses poll into EDA.Poll struct" do
      raw = %{
        "id" => "msg1",
        "poll" => %{
          "question" => %{"text" => "Best?"},
          "answers" => [%{"answer_id" => 1, "poll_media" => %{"text" => "A"}}],
          "allow_multiselect" => false,
          "layout_type" => 1
        }
      }

      msg = Message.from_raw(raw)
      assert %EDA.Poll{question: "Best?"} = msg.poll
      assert length(msg.poll.answers) == 1
    end
  end

  # ── Entity Manager ──

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn ->
      Application.delete_env(:eda, :base_url)
    end)

    {:ok, bypass: bypass}
  end

  defp json(conn, body, status \\ 200) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  defp sample_msg do
    Message.from_raw(%{"id" => "msg1", "channel_id" => "ch1", "content" => "hello"})
  end

  describe "fetch_message/2" do
    test "returns a Message struct from REST", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/ch1/messages/msg1", fn conn ->
        json(conn, %{"id" => "msg1", "channel_id" => "ch1", "content" => "hello"})
      end)

      assert {:ok, %Message{id: "msg1", content: "hello"}} = Message.fetch_message("ch1", "msg1")
    end
  end

  describe "edit/2" do
    test "returns an updated Message struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/channels/ch1/messages/msg1", fn conn ->
        json(conn, %{"id" => "msg1", "channel_id" => "ch1", "content" => "edited"})
      end)

      assert {:ok, %Message{content: "edited"}} = Message.edit(sample_msg(), %{content: "edited"})
    end
  end

  describe "delete/1" do
    test "deletes a message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/channels/ch1/messages/msg1", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Message.delete(sample_msg())
    end
  end

  describe "pin/2" do
    test "pins a message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/channels/ch1/messages/pins/msg1", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Message.pin(sample_msg())
    end

    test "forwards the audit log reason", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/channels/ch1/messages/pins/msg1", fn conn ->
        assert {"x-audit-log-reason", "why"} in conn.req_headers
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Message.pin(sample_msg(), reason: "why")
    end
  end

  describe "unpin/2" do
    test "unpins a message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/channels/ch1/messages/pins/msg1", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Message.unpin(sample_msg())
    end
  end

  describe "react/2" do
    test "adds a reaction", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PUT",
        "/channels/ch1/messages/msg1/reactions/%F0%9F%91%8D/@me",
        fn conn ->
          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert :ok = Message.react(sample_msg(), "👍")
    end
  end

  describe "reply/2" do
    test "replies to a message and returns Message struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/ch1/messages", fn conn ->
        json(conn, %{
          "id" => "msg2",
          "channel_id" => "ch1",
          "content" => "reply text",
          "message_reference" => %{"message_id" => "msg1"}
        })
      end)

      assert {:ok, %Message{id: "msg2", content: "reply text"}} =
               Message.reply(sample_msg(), "reply text")
    end
  end
end
