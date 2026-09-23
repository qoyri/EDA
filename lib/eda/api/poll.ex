defmodule EDA.API.Poll do
  @moduledoc """
  REST API endpoints for Discord message polls.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc """
  Expires a poll before its scheduled end time.

  Returns the updated message containing the expired poll.

  ## Parameters

    * `channel_id` - The channel containing the poll message
    * `message_id` - The message containing the poll

  ## Examples

      EDA.API.Poll.expire("123456", "789012")
  """
  @spec expire(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def expire(channel_id, message_id) do
    post("/channels/#{channel_id}/polls/#{message_id}/expire", %{})
  end

  @doc """
  Gets users who voted for a specific poll answer, as Discord sends them: `%{"users" => [user]}`.

  ## Parameters

    * `channel_id` - The channel containing the poll message
    * `message_id` - The message containing the poll
    * `answer_id` - The answer ID to get voters for

  ## Options

    * `:after` - Snowflake ID for pagination (get users after this ID)
    * `:limit` - Number of users to return (1-100, default: 25)

  ## Examples

      EDA.API.Poll.get_voters("123456", "789012", 1)
      EDA.API.Poll.get_voters("123456", "789012", 1, after: "111222", limit: 50)
  """
  @spec get_voters(String.t() | integer(), String.t() | integer(), integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_voters(channel_id, message_id, answer_id, opts \\ []) do
    query =
      Enum.reject(
        [after: opts[:after], limit: opts[:limit]],
        fn {_, v} -> is_nil(v) end
      )

    path = with_query("/channels/#{channel_id}/polls/#{message_id}/answers/#{answer_id}", query)
    get(path)
  end
end
