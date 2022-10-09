defmodule DouYin.Configuration do
  @moduledoc false

  def normalize(config) do
    Keyword.merge(
      [
        finch_pool: [size: 32, count: 8],
        refresher: DouYin.Refresher.Default,
        refresh_settings: %{},
        clients: []
      ],
      config
    )
  end
end
