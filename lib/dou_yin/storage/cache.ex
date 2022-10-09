defmodule DouYin.Storage.Cache do
  @moduledoc "缓存存储器"

  @type cache_id :: DouYin.app_id()
  @type cache_sub_key :: term
  @type cache_key :: {cache_id, cache_sub_key}
  @type cache_value :: term

  @compile {:inline, put_cache: 2, get_cache: 1, del_cache: 1}

  def init_table() do
    :ets.new(:douyin, [:named_table, :set, :public, read_concurrency: true])
  end

  @spec set_client(DouYin.client()) :: true
  def set_client(client) do
    app_id = client.app_id()
    code_name = client.code_name()
    Enum.uniq([app_id, code_name]) |> Enum.map(&{{&1, :client}, client}) |> put_caches()
  end

  @spec search_client(DouYin.app_id() | DouYin.code_name()) :: nil | DouYin.client()
  def search_client(app_flag), do: get_cache(app_flag, :client)

  @spec put_cache(cache_id(), cache_sub_key(), cache_value()) :: true
  def put_cache(id, sub_key, value) do
    put_cache({id, sub_key}, value)
  end

  @spec put_cache(cache_key(), cache_value()) :: true
  def put_cache(key, value) do
    :ets.insert(:douyin, {key, value})
  end

  @spec put_caches([{cache_key(), cache_value()}]) :: true
  def put_caches(list) when is_list(list) do
    :ets.insert(:douyin, list)
  end

  @spec get_cache(cache_id(), cache_sub_key()) :: nil | cache_value()
  def get_cache(id, sub_key) do
    get_cache({id, sub_key})
  end

  @spec get_cache(cache_key()) :: nil | cache_value()
  def get_cache(key) do
    case :ets.lookup(:douyin, key) do
      [{_, value}] -> value
      _ -> nil
    end
  end

  @spec del_cache(cache_id(), cache_sub_key()) :: true
  def del_cache(id, sub_key) do
    del_cache({id, sub_key})
  end

  @spec del_cache(cache_key()) :: true
  def del_cache(key) do
    :ets.delete(:douyin, key)
  end
end
