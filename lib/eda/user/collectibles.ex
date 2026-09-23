defmodule EDA.User.Collectibles do
  @moduledoc """
  What a user has collected from the shop and is showing on their profile.

  Discord documents one kind so far, the nameplate (`EDA.User.Nameplate`); the object is a map
  so more can appear, and an unknown kind is kept raw in `other` rather than dropped.

  ## Example

      %EDA.User.Collectibles{
        nameplate: %EDA.User.Nameplate{asset: "nameplates/zodiac/virgo/", palette: "lemon"}
      }
  """

  use EDA.Event.Access

  defstruct [:nameplate, other: %{}]

  @type t :: %__MODULE__{
          nameplate: EDA.User.Nameplate.t() | nil,
          other: map()
        }

  @doc "Parses the raw `collectibles` object. Returns `nil` when absent or null."
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      nameplate: EDA.User.Nameplate.from_raw(:maps.get("nameplate", raw, nil)),
      other: Map.drop(raw, ["nameplate"])
    }
  end

  def from_raw(_), do: nil
end
