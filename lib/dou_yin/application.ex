defmodule DouYin.Application do
  @moduledoc false

  use Application
  @app :douyin

  @impl true
  def start(_type, _args) do
    DouYin.Storage.Cache.init_table()
    config = Application.get_all_env(@app) |> DouYin.Configuration.normalize()

    children = [
      {Finch, name: DouYin.Finch, pools: %{:default => config[:finch_pool]}},
      {config[:refresher], config[:refresh_settings]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: DouYin.Supervisor)
  end
end
