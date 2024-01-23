defmodule DouYin.Refresher.Default do
  @moduledoc """
  AccessToken 刷新器 - 用于定时刷新 AccessToken

  [官方说明](https://developers.weixin.qq.com/doc/offiaccount/Getting_Started/Getting_Started_Guide.html#_1-5-%E9%87%8D%E8%A6%81%E4%BA%8B%E6%83%85%E6%8F%90%E5%89%8D%E4%BA%A4%E4%BB%A3)

  本模块为默认的刷新器

  需要修改为自定义的刷新器，可以这样配置：

      config :douyin, :refresher, YourRefresher

  修改刷新器的配置，支持多种配置方式：

  ### 方式1

      config :douyin, :refresh_settings, [ClientA, ClientB, ClientC]

  以上配置会自动为三个 `Client` 定时刷新 `AccessToken` ，
  默认会在 `AccessToken` 过期前 `30` 分钟刷新，
  `AccessToken` 刷新失败的重试间隔为 `1` 分钟，
  可以通过接口 获取默认的 `AccessToken` 刷新列表：`DouYin.Refresher.DefaultSettings.get_refresh_options_by_client/1`

  ### 方式2

      config :douyin, :refresh_settings, [{ClientA, client_setting}, ClientB, ClientC]
      # or
      config :douyin, :refresh_settings, %{ClientA => client_setting, ClientB => client_setting, ClientC => client_setting}

  `client_setting` 配置说明见：`t:client_setting/0`

  为了适应 `Storage` 在 `Refresher` 启动之后才启动，可以开启延时启动刷新:

      config :douyin, #{inspect(__MODULE__)}, wait_for_signal: true

  当所有的 `Storage` 都已经完成，可以即可通过 `#{inspect(__MODULE__)}.start_monitor/0` 方法刷新 `AccessToken`

  不配置默认为立即启动刷新
  """
  use GenServer
  require Logger
  alias DouYin.Storage.Adapter, as: StorageAdapter
  alias DouYin.{Utils, Storage.Cache, Refresher.DefaultSettings}

  # 过期前 30 分钟刷新
  @refresh_before_expired 30 * 60
  # 刷新失败重试时间间隔 1 分钟
  @refresh_retry_interval 60

  @typedoc """
  在 `AccessToken` 超时前多少秒刷新，单位：秒
  """
  @type refresh_before_expired :: non_neg_integer
  @typedoc "刷新 `AccessToken` 失败的重试间隔，单位：秒"
  @type refresh_retry_interval :: non_neg_integer
  @typedoc """

  option
  - `:refresh_before_expired`: 在 `AccessToken` 超时前多少秒刷新，单位：秒，可选，
  默认值：`#{@refresh_before_expired}` 秒
  - `:refresh_retry_interval`: 刷新 `AccessToken` 失败的重试间隔，单位：秒，可选，默认值：`#{@refresh_retry_interval * 1000}` 秒
  - `:refresh_options`: 刷新 `AccessToken` 配置，可选，默认值：`DouYin.Refresher.DefaultSettings.get_refresh_options_by_client/1` 的输出结果
  """
  @type client_setting ::
          %{
            optional(:refresh_before_expired) => refresh_before_expired,
            optional(:refresh_retry_interval) => refresh_retry_interval,
            optional(:refresh_options) => DefaultSettings.refresh_options()
          }
  @type client_settings :: [DouYin.client()] | %{DouYin.client() => client_setting}
  @type state :: %{
          :wait_for_signal => boolean,
          :clients => [DouYin.client()],
          DouYin.client() => client_setting
        }

  @spec start_monitor() :: :ok
  def start_monitor do
    GenServer.call(__MODULE__, :start_monitor)
  end

  @spec add(DouYin.client(), client_setting) :: :ok
  def add(client, opts \\ %{}) do
    GenServer.call(__MODULE__, {:add, client, Map.new(opts)})
  end

  @spec remove(DouYin.client()) :: :ok | :not_found
  def remove(client) do
    GenServer.call(__MODULE__, {:remove, client})
  end

  @spec refresh(DouYin.client()) :: :ok | :not_found
  def refresh(client) do
    GenServer.call(__MODULE__, {:refresh, client})
  end

  @spec refresh_key(
          DouYin.client(),
          StorageAdapter.store_id(),
          StorageAdapter.store_key(),
          StorageAdapter.value(),
          expires :: integer()
        ) :: :ok
  def refresh_key(client, store_id, store_key, value, expires) do
    GenServer.cast(__MODULE__, {:refresh_key, client, store_id, store_key, value, expires})
  end

  @spec start_link(client_settings) :: GenServer.on_start()
  def start_link(client_settings \\ %{}) do
    GenServer.start_link(__MODULE__, client_settings, name: __MODULE__)
  end

  @impl true
  def init(client_settings) do
    state =
      Map.new(client_settings, fn
        client when is_atom(client) ->
          {client, init_client_options(client, %{})}

        {client, opts} ->
          {client, init_client_options(client, opts)}
      end)

    clients = Map.keys(state)

    options =
      :douyin
      |> Application.get_env(__MODULE__, %{})
      |> Map.new()

    state =
      %{wait_for_signal: false}
      |> Map.merge(options)
      |> Map.merge(state)
      |> Map.put(:clients, clients)

    continue =
      if state.wait_for_signal do
        :wait_for_signal
      else
        :start_monitor
      end

    {:ok, state, {:continue, continue}}
  end

  @impl true
  def handle_continue(:wait_for_signal, state) do
    {:noreply, state}
  end

  def handle_continue(:start_monitor, state) do
    state =
      Enum.reduce(state.clients, state, fn client, acc ->
        options = start_monitor_client(client, Map.get(acc, client))
        Map.put(acc, client, options)
      end)

    {:noreply, %{state | wait_for_signal: false}}
  end

  @impl true
  def handle_call(:start_monitor, _from, state) do
    {:reply, :ok, state, {:continue, :start_monitor}}
  end

  def handle_call({:add, client, options}, _from, state) do
    state =
      if client in state.clients do
        remove_client(state, client)
      else
        state
      end
      |> add_client(client, options)

    {:reply, :ok, state}
  end

  def handle_call({:remove, client}, _from, state) do
    if client in state.clients do
      state = remove_client(state, client)
      {:reply, :ok, state}
    else
      {:reply, :not_found, state}
    end
  end

  def handle_call({:refresh, client}, _from, state) do
    with opts when is_map(opts) <- Map.get(state, client) do
      opts = do_refresh(client, opts)
      state = Map.put(state, client, opts)
      {:reply, :ok, state}
    else
      _ ->
        {:reply, :not_found, state}
    end
  end

  @impl true
  def handle_cast({:refresh_key, client, store_id, store_key, value, expires}, state) do
    cache_and_store(store_id, store_key, value, expires, client)
    {:ok, state}
  end

  @impl true
  def handle_info(
        {:timeout, _timer,
         {:refresh_token, %{store_id: store_id, store_key: store_key, client: client}}},
        state
      ) do
    case Map.get(state, client) do
      opts when opts != nil ->
        key = {store_id, store_key}
        {{_key, fun, _timer}, refresh_options} = List.keytake(opts.refresh_options, key, 0)
        timer = refresh_token(store_id, store_key, fun, client, opts)

        state =
          Map.put(state, client, %{opts | refresh_options: [{key, fun, timer} | refresh_options]})

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  defp cache_and_store(store_id, store_key, value, expires, client) do
    store_map = %{"value" => value, "expired_time" => expires}
    Cache.put_cache(store_id, store_key, value)
    Cache.put_cache({:store_map, store_id}, store_key, store_map)

    with storage when storage != nil <- client.storage() do
      result = storage.store(store_id, store_key, store_map)

      Logger.info(
        "Call #{inspect(storage)}.restore(#{store_id}, #{store_key}) => #{inspect(result)}."
      )
    end
  end

  defp restore_and_cache(store_id, store_key, client) do
    with storage when storage != nil <- client.storage(),
         {:ok, %{"value" => value, "expired_time" => expires} = store_map} <-
           storage.restore(store_id, store_key) do
      diff = expires - Utils.now_unix()

      if diff > 0 do
        Cache.put_cache(store_id, store_key, value)
        Cache.put_cache({:store_map, store_id}, store_key, store_map)

        Logger.info(
          "Call #{inspect(storage)}.restore(#{store_id}, #{store_key}) succeed, the expires_in is: #{diff}s."
        )

        {true, diff}
      else
        Logger.info(
          "Call #{inspect(storage)}.restore(#{store_id}, #{store_key}) succeed, but the token expired."
        )

        false
      end
    else
      nil ->
        false

      error ->
        Logger.warning(
          "Call #{inspect(client.storage())}.restore(#{store_id}, #{store_key}) failed, return error: #{inspect(error)}."
        )

        false
    end
  end

  defp init_client_options(client, options) do
    Logger.info(
      "Initialize DouYin Client: #{inspect(client)} by AppType: #{client.app_type()}, Storage: #{inspect(client.storage())}."
    )

    default_refresh_before_expired = @refresh_before_expired

    options =
      Map.merge(options, %{
        refresh_before_expired:
          Map.get(options, :refresh_before_expired, default_refresh_before_expired),
        refresh_retry_interval:
          Map.get(options, :refresh_retry_interval, @refresh_retry_interval) * 1000
      })

    Cache.set_client(client)

    refresh_options = init_refresh_options(client, options)
    Map.put(options, :refresh_options, refresh_options)
  end

  defp start_monitor_client(client, options) do
    Logger.info("Monitoring DouYin Client: #{inspect(client)}.")

    refresh_options =
      for {{store_id, store_key}, fun, _timer} <- options.refresh_options do
        timer =
          case restore_and_cache(store_id, store_key, client) do
            false ->
              refresh_token(store_id, store_key, fun, client, options)

            {true, expires_in} ->
              ((expires_in - options.refresh_before_expired) * 1000)
              |> max(0)
              |> start_refresh_token_timer(store_id, store_key, client)
          end

        {{store_id, store_key}, fun, timer}
      end

    %{options | refresh_options: refresh_options}
  end

  defp do_refresh(client, %{refresh_options: refresh_options} = opts) do
    Logger.info(
      "Refreshing DouYin Client: #{inspect(client)} with list: #{inspect(refresh_options)}."
    )

    refresh_options =
      for {{store_id, store_key}, fun, timer} <- refresh_options do
        cancel_timer(timer)
        timer = refresh_token(store_id, store_key, fun, client, opts)
        {{store_id, store_key}, fun, timer}
      end

    %{opts | refresh_options: refresh_options}
  end

  defp cancel_timer(nil), do: :ignore
  defp cancel_timer(timer), do: :erlang.cancel_timer(timer)

  defp refresh_token(store_id, store_key, fun, client, options) do
    case fun.(client) do
      {:ok, list, expires_in} when is_list(list) ->
        now = Utils.now_unix()

        Enum.each(list, fn {key, token, expires_in} ->
          expires = now + expires_in
          cache_and_store(store_id, key, token, expires, client)
        end)

        Logger.info(
          "Refresh app_id: #{store_id}, key: #{store_key} succeed, get expires_in: #{expires_in}s."
        )

        ((expires_in - options.refresh_before_expired) * 1000)
        |> max(options.refresh_retry_interval)

      {:ok, token, expires_in} ->
        expires = Utils.now_unix() + expires_in
        cache_and_store(store_id, store_key, token, expires, client)

        Logger.info(
          "Refresh app_id: #{store_id}, key: #{store_key} succeed, get expires_in: #{expires_in}s."
        )

        ((expires_in - options.refresh_before_expired) * 1000)
        |> max(options.refresh_retry_interval)

      error ->
        refresh_retry_interval = options.refresh_retry_interval

        Logger.warning(
          "Refresh app_id: #{store_id}, key: #{store_key} failed, return error: #{inspect(error)}, Will be retry again #{refresh_retry_interval}s later."
        )

        refresh_retry_interval
    end
    |> start_refresh_token_timer(store_id, store_key, client)
  end

  defp start_refresh_token_timer(time, store_id, store_key, client) do
    Logger.info("Start Refresh Timer for app_id: #{store_id}, key: #{store_key}, time: #{time}s.")
    info = %{store_id: store_id, store_key: store_key, client: client}
    :erlang.start_timer(time, self(), {:refresh_token, info})
  end

  defp init_refresh_options(client, opts) do
    refresh_options =
      case Map.get(opts, :refresh_options) do
        fun when is_function(fun, 0) ->
          fun.()

        fun when is_function(fun, 1) ->
          fun.(client)

        refresh_options when is_list(refresh_options) ->
          refresh_options

        nil ->
          DefaultSettings.get_refresh_options_by_client(client)
      end

    for {store_id, store_key, fun} <- refresh_options do
      {{store_id, store_key}, fun, nil}
    end
  end

  defp add_client(state, client, options) do
    options =
      if state.wait_for_signal do
        init_client_options(client, options)
      else
        options = init_client_options(client, options)
        start_monitor_client(client, options)
      end

    state
    |> Map.put(client, options)
    |> Map.put(:clients, [client | state.clients])
  end

  defp remove_client(state, client) do
    Logger.info("Removing DouYin Client: #{inspect(client)}.")
    {get, state} = Map.pop(state, client)
    clients = List.delete(state.clients, client)

    with {_client, opts} <- get do
      Enum.each(opts.refresh_options, fn {_key, _fun, timer} ->
        cancel_timer(timer)
      end)
    end

    %{state | clients: clients}
  end
end
