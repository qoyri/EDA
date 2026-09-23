defmodule EDA.Guild.WelcomeScreen do
  @moduledoc """
  The screen a Community guild shows new members: a `description`, and up to five
  `welcome_channels` suggested to them, each an `EDA.Guild.WelcomeScreen.Channel`.
  """

  use EDA.Event.Access

  defstruct [:description, welcome_channels: []]

  @type t :: %__MODULE__{
          description: String.t() | nil,
          welcome_channels: [EDA.Guild.WelcomeScreen.Channel.t()]
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      description: :maps.get("description", raw, nil),
      welcome_channels:
        Enum.map(
          :maps.get("welcome_channels", raw, nil) || [],
          &EDA.Guild.WelcomeScreen.Channel.from_raw/1
        )
    }
  end
end

defimpl Jason.Encoder, for: EDA.Guild.WelcomeScreen do
  def encode(screen, opts), do: screen |> Map.from_struct() |> Jason.Encode.map(opts)
end
