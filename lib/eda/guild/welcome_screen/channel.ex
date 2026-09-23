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
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: raw["channel_id"],
      description: raw["description"],
      emoji_id: raw["emoji_id"],
      emoji_name: raw["emoji_name"]
    }
  end
end

defimpl Jason.Encoder, for: EDA.Guild.WelcomeScreen.Channel do
  def encode(channel, opts), do: channel |> Map.from_struct() |> Jason.Encode.map(opts)
end
