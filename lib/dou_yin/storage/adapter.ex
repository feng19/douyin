defmodule DouYin.Storage.Adapter do
  @moduledoc "存储器适配器"

  @typedoc "存储器"
  @type t :: module
  @type store_id :: String.t()
  @type store_key :: atom | String.t()
  @type value :: map

  @callback store(store_id, store_key, value) :: :ok | any
  @callback restore(store_id, store_key) :: {:ok, value} | any
end
