defmodule EDA.Voice.Supervisor do
  @moduledoc """
  Supervision tree for the voice subsystem.

  Children:
  - `Registry` - Maps `{:session, guild_id}` to voice session PIDs
  - `EDA.Voice` - GenServer managing voice state per guild
  - `DynamicSupervisor` - Starts `EDA.Voice.Session` processes per guild
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Registry, keys: :unique, name: EDA.Voice.Registry},
      EDA.Voice,
      {DynamicSupervisor, name: EDA.Voice.DynamicSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
