defmodule EDA.SKU do
  @moduledoc """
  Something an app sells: a subscription, a durable one-time purchase, or a consumable.

  `type` is `:durable`, `:consumable`, `:subscription`, or `:subscription_group` for the group
  Discord creates around each subscription SKU. A user or a guild that bought one holds an
  `EDA.Entitlement` whose `sku_id` is the SKU's `id`.

      {:ok, skus} = EDA.SKU.list()
      premium = Enum.find(skus, &(&1.slug == "premium"))
  """

  use EDA.Event.Access

  defstruct [:id, :type, :application_id, :name, :slug, :flags]

  @type type :: :durable | :consumable | :subscription | :subscription_group | integer()

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: type() | nil,
          application_id: String.t() | nil,
          name: String.t() | nil,
          slug: String.t() | nil,
          flags: non_neg_integer() | nil
        }

  @types %{2 => :durable, 3 => :consumable, 5 => :subscription, 6 => :subscription_group}

  @doc """
  A SKU as Discord sends it.

      iex> EDA.SKU.from_raw(%{"id" => "1", "type" => 5, "name" => "Premium", "flags" => 260})
      %EDA.SKU{id: "1", type: :subscription, name: "Premium", flags: 260}
  """
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      type: EDA.Enum.name(@types, :maps.get("type", raw, nil)),
      application_id: :maps.get("application_id", raw, nil),
      name: :maps.get("name", raw, nil),
      slug: :maps.get("slug", raw, nil),
      flags: :maps.get("flags", raw, nil)
    }
  end

  @doc """
  The SKU's flags, as `EDA.SKU.Flags` names them.

      iex> EDA.SKU.flags(%EDA.SKU{flags: 260})
      [:available, :user_subscription]
  """
  @spec flags(t() | map()) :: [EDA.SKU.Flags.flag()]
  def flags(%__MODULE__{flags: flags}), do: EDA.SKU.Flags.to_list(flags)
  def flags(%{"flags" => flags}), do: EDA.SKU.Flags.to_list(flags)
  def flags(_), do: []

  @doc """
  Whether `flags` carries a flag.

      iex> EDA.SKU.flag?(%EDA.SKU{flags: 260}, :available)
      true
  """
  @spec flag?(t() | map(), EDA.SKU.Flags.flag()) :: boolean()
  def flag?(%__MODULE__{flags: flags}, flag), do: EDA.SKU.Flags.has?(flags, flag)
  def flag?(%{"flags" => flags}, flag), do: EDA.SKU.Flags.has?(flags, flag)
  def flag?(_, _flag), do: false

  @doc "Lists the app's SKUs as structs. See `EDA.API.SKU.list/0`."
  @spec list() :: {:ok, [t()]} | {:error, term()}
  def list do
    case EDA.API.SKU.list() do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &from_raw/1)}
      {:error, _} = err -> err
    end
  end
end
