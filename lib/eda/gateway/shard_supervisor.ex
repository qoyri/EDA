defmodule EDA.Gateway.ShardSupervisor do
  @moduledoc """
  Top-level supervisor for the Gateway sharding system.

  Manages:
  - `Registry` — shard_id → Connection pid mapping (always up-to-date)
  - `DynamicSupervisor` — supervises individual shard Connections
  - `ShardManager` — orchestrates shard lifecycle

  Uses `:rest_for_one` strategy so that if the Registry crashes,
  the DynamicSupervisor and ShardManager are restarted too.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    token = Keyword.get(opts, :token)

    children =
      if token do
        [
          {Registry, keys: :unique, name: EDA.Gateway.Registry},
          {DynamicSupervisor, name: EDA.Gateway.DynamicSupervisor, strategy: :one_for_one},
          {EDA.Gateway.ShardManager, token: token}
        ]
      else
        # EDA.Application has already warned about the missing token.
        []
      end

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
