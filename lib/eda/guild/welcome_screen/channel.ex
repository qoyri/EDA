defmodule EDA.Guild.WelcomeScreen.Channel do
  @moduledoc """
  A channel the welcome screen suggests, with the line shown beside it and its emoji: a custom
  one by `emoji_id`, or a Unicode one in `emoji_name`.

  It encodes as Discord takes it, so a screen read with `EDA.API.Guild.welcome_screen/1` can be
  edited and sent back to `EDA.API.Guild.modify_welcome_screen/2`.
  """

  use EDA.Event.Access

  defstruct [:channel_id, :description, :emoji_id, :emoji_name]

  @type t :: %__MODULE__{
          channel_id: String.t() | nil,
          description: String.t() | nil,
          emoji_id: String.t() | nil,
          emoji_name: String.t() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: :maps.get("channel_id", raw, nil),
      description: :maps.get("description", raw, nil),
      emoji_id: :maps.get("emoji_id", raw, nil),
      emoji_name: :maps.get("emoji_name", raw, nil)
    }
  end
end

defimpl Jason.Encoder, for: EDA.Guild.WelcomeScreen.Channel do
  def encode(channel, opts), do: channel |> Map.from_struct() |> Jason.Encode.map(opts)
end
