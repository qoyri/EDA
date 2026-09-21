defmodule EDA.API.MessageSearchTest do
  @moduledoc """
  Covers guild message search.

  Three things here are not guessable from the endpoint's signature, and all three were
  confirmed against the live API on 2026-09-20:

    * `messages` is a list of **lists** — context groups, with the match carrying
      `"hit" => true` — so a naive parse produces lists where messages were expected;
    * multi-valued filters are **repeated query keys**, which `URI.encode_query/1` cannot
      express and raises on;
    * a guild still being indexed answers **HTTP 202**, a success status carrying no
      results, which would otherwise read as "nothing matched".
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  alias EDA.API.Message

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn -> Application.delete_env(:eda, :base_url) end)

    {:ok, bypass: bypass}
  end

  defp expect_search(bypass, test_pid, body) do
    Bypass.expect_once(bypass, "GET", "/guilds/111/messages/search", fn conn ->
      send(test_pid, {:query, conn.query_string})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(body))
    end)
  end

  defp results_body(groups, extra \\ %{}) do
    Map.merge(
      %{
        "analytics_id" => "abc",
        "doing_deep_historical_index" => false,
        "total_results" => length(groups),
        "messages" => groups
      },
      extra
    )
  end

  defp message(id, content, extra \\ %{}) do
    Map.merge(%{"id" => id, "content" => content, "channel_id" => "c1"}, extra)
  end

  describe "the query string" do
    test "a multi-valued filter becomes a repeated key", %{bypass: bypass} do
      expect_search(bypass, self(), results_body([]))

      assert {:ok, _} = Message.search("111", channel_id: ["c1", "c2"], limit: 5)

      assert_receive {:query, query}
      pairs = URI.decode_query(query)
      # URI.decode_query collapses duplicates, so check the raw string as well
      assert query =~ "channel_id=c1"
      assert query =~ "channel_id=c2"
      assert pairs["limit"] == "5"
    end

    test "atoms are written as Discord's strings" do
      # :has and :sort_by are far nicer as atoms than as string literals.
      bypass = Bypass.open()
      Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
      expect_search(bypass, self(), results_body([]))

      assert {:ok, _} = Message.search("111", has: [:image, :link], sort_by: :relevance)

      assert_receive {:query, query}
      assert query =~ "has=image"
      assert query =~ "has=link"
      assert query =~ "sort_by=relevance"
    end

    test "integer ids are accepted, since snowflakes are often held as ints",
         %{bypass: bypass} do
      expect_search(bypass, self(), results_body([]))

      assert {:ok, _} = Message.search("111", author_id: [123, 456])

      assert_receive {:query, query}
      assert query =~ "author_id=123"
      assert query =~ "author_id=456"
    end

    test "booleans survive", %{bypass: bypass} do
      expect_search(bypass, self(), results_body([]))

      assert {:ok, _} = Message.search("111", pinned: true, include_nsfw: false)

      assert_receive {:query, query}
      assert query =~ "pinned=true"
      assert query =~ "include_nsfw=false"
    end

    test "no options means no query string at all", %{bypass: bypass} do
      expect_search(bypass, self(), results_body([]))

      assert {:ok, _} = Message.search("111")
      assert_receive {:query, ""}
    end
  end

  describe "validation, before Discord answers with an opaque 50035" do
    setup %{bypass: bypass} do
      # No request should leave the process for any of these.
      Bypass.down(bypass)
      :ok
    end

    test "an unknown option is refused instead of being sent as a junk parameter" do
      # Discord ignores query parameters it does not recognise, so a typo would return the
      # guild's whole history while looking like a filtered search. A keyword list has no
      # compile-time protection against a misspelt key, so the function checks its own.
      assert_raise ArgumentError, ~r/Message.search\/2: unknown option \[:contnet\]/, fn ->
        Message.search("111", contnet: "typo")
      end

      assert_raise ArgumentError, ~r/unknown options \[:bar, :foo\]/, fn ->
        Message.search("111", foo: 1, bar: 2)
      end
    end

    test "the refusal lists what is accepted" do
      error = assert_raise(ArgumentError, fn -> Message.search("111", nope: 1) end)

      assert error.message =~ ":content"
      assert error.message =~ ":attachment_filename"
      assert error.message =~ ":sort_by"
    end

    test "every documented option is accepted" do
      opts = [
        content: "x",
        channel_id: ["1"],
        author_id: ["1"],
        author_type: [:user],
        mentions: ["1"],
        mentions_role_id: ["1"],
        mention_everyone: true,
        replied_to_user_id: ["1"],
        replied_to_message_id: ["1"],
        pinned: false,
        has: [:link],
        embed_type: ["image"],
        embed_provider: ["x"],
        link_hostname: ["example.com"],
        attachment_filename: ["cat.png"],
        attachment_extension: ["png"],
        sort_by: :timestamp,
        sort_order: :desc,
        limit: 25,
        offset: 0,
        slop: 2,
        min_id: "1",
        max_id: "2",
        include_nsfw: false
      ]

      # Bypass is down, so reaching the transport proves validation let everything through.
      assert {:error, _} = Message.search("111", opts)
    end

    test "limit is 1..25" do
      assert_raise ArgumentError, ~r/:limit must be between 1 and 25/, fn ->
        Message.search("111", limit: 26)
      end

      assert_raise ArgumentError, ~r/:limit must be between 1 and 25/, fn ->
        Message.search("111", limit: 0)
      end
    end

    test "offset caps at 9975" do
      assert_raise ArgumentError, ~r/:offset caps at 9975/, fn ->
        Message.search("111", offset: 9976)
      end
    end

    test "slop caps at 100" do
      assert_raise ArgumentError, ~r/:slop caps at 100/, fn ->
        Message.search("111", slop: 101)
      end
    end

    test "content is limited to 1024 characters" do
      assert_raise ArgumentError, ~r/:content is limited to 1024/, fn ->
        Message.search("111", content: String.duplicate("x", 1025))
      end
    end

    test "the per-filter maximums are enforced by name" do
      assert_raise ArgumentError, ~r/:channel_id accepts at most 500 values/, fn ->
        Message.search("111", channel_id: Enum.map(1..501, &to_string/1))
      end

      assert_raise ArgumentError, ~r/:author_id accepts at most 100 values/, fn ->
        Message.search("111", author_id: Enum.map(1..101, &to_string/1))
      end
    end

    test "enumerated options name what they accept" do
      assert_raise ArgumentError, ~r/:has accepts/, fn ->
        Message.search("111", has: [:nonsense])
      end

      assert_raise ArgumentError, ~r/:sort_by accepts/, fn ->
        Message.search("111", sort_by: :popularity)
      end

      assert_raise ArgumentError, ~r/:sort_order accepts/, fn ->
        Message.search("111", sort_order: :sideways)
      end

      assert_raise ArgumentError, ~r/:author_type accepts/, fn ->
        Message.search("111", author_type: [:human])
      end
    end

    test "a string that is not a known value is refused, not turned into an atom" do
      # String.to_existing_atom/1 would raise a bare ArgumentError with no context.
      assert_raise ArgumentError, ~r/:has accepts/, fn ->
        Message.search("111", has: ["definitely_not_a_filter"])
      end
    end

    test "the documented values are all accepted" do
      # Validation must let these through. Bypass is down, so the call gets as far as the
      # transport and fails there — which is the proof that nothing raised earlier.
      for value <- [:image, :sound, :video, :file, :sticker, :embed, :link, :poll, :snapshot] do
        assert {:error, _} = Message.search("111", has: [value])
      end

      for value <- [:user, :bot, :webhook] do
        assert {:error, _} = Message.search("111", author_type: [value])
      end

      for value <- [:timestamp, :relevance] do
        assert {:error, _} = Message.search("111", sort_by: value)
      end
    end
  end

  describe "an index that is not ready" do
    test "a 202 carrying code 110000 is an error, not an empty result set",
         %{bypass: bypass} do
      # HTTP 202 is a success status, so this would otherwise parse as "nothing matched".
      Bypass.expect_once(bypass, "GET", "/guilds/111/messages/search", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          202,
          Jason.encode!(%{
            "code" => 110_000,
            "message" => "Index not yet available. Try again later",
            "retry_after" => 2,
            "documents_indexed" => 0
          })
        )
      end)

      assert {:error, {:index_pending, 2}} = Message.search("111", content: "x")
    end

    test "the entity wrapper passes that through rather than parsing it",
         %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/messages/search", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(202, Jason.encode!(%{"code" => 110_000, "retry_after" => 0}))
      end)

      assert {:error, {:index_pending, 0}} = EDA.Message.search("111")
    end
  end

  describe "EDA.Message.search/2 flattens the context groups" do
    test "results are the matches, groups keep the neighbours", %{bypass: bypass} do
      groups = [
        [message("m1", "first match", %{"hit" => true})],
        [
          message("m2", "before"),
          message("m3", "second match", %{"hit" => true}),
          message("m4", "after")
        ]
      ]

      expect_search(bypass, self(), results_body(groups, %{"total_results" => 1034}))

      assert {:ok, found} = EDA.Message.search("111", content: "match")

      assert Enum.map(found.results, & &1.id) == ["m1", "m3"]
      assert Enum.map(found.groups, &length/1) == [1, 3]
      assert [%EDA.Message{} | _] = found.results
      assert found.total_results == 1034
      assert found.indexing? == false
    end

    test "a group with no hit falls back to its first message", %{bypass: bypass} do
      expect_search(bypass, self(), results_body([[message("m1", "a"), message("m2", "b")]]))

      assert {:ok, %{results: [result]}} = EDA.Message.search("111")
      assert result.id == "m1"
    end

    test "indexing? reports Discord's deep historical index flag", %{bypass: bypass} do
      expect_search(
        bypass,
        self(),
        results_body([], %{"doing_deep_historical_index" => true})
      )

      assert {:ok, %{indexing?: true}} = EDA.Message.search("111")
    end

    test "no matches is an empty result set, not an error", %{bypass: bypass} do
      expect_search(bypass, self(), results_body([], %{"total_results" => 0}))

      assert {:ok, found} = EDA.Message.search("111", content: "nothing")
      assert found.results == []
      assert found.groups == []
      assert found.total_results == 0
    end

    test "a payload without the messages key does not crash", %{bypass: bypass} do
      expect_search(bypass, self(), %{"total_results" => 0})

      assert {:ok, found} = EDA.Message.search("111")
      assert found.results == []
      assert found.total_results == 0
    end
  end
end
