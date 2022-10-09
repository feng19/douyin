defmodule DouYin.Refresher.DefaultSettings do
  @moduledoc """
  刷新 `AccessToken` 的方法
  """

  require Logger

  @type key_name :: atom
  @type token :: String.t()
  @type expires_in :: non_neg_integer
  @type token_list :: [{key_name, token, expires_in}]
  @type refresh_fun_result ::
          {:ok, token, expires_in} | {:ok, token_list, expires_in} | {:error, any}
  @type refresh_fun :: (DouYin.client() -> refresh_fun_result)
  @type refresh_option :: {DouYin.Storage.Adapter.store_id(), key_name, refresh_fun}
  @type refresh_options :: [refresh_option]

  @spec get_refresh_options_by_client(DouYin.client()) :: refresh_options
  def get_refresh_options_by_client(client) do
    case client.app_type() do
      :mini_app ->
        check_secret(client)
        mini_app_refresh_options(client)
    end
  end

  defp check_secret(client) do
    unless function_exported?(client, :app_secret, 0) do
      raise RuntimeError, "Please set :app_secret when defining #{inspect(client)}."
    end
  end

  @doc """
  输出[公众号]的 `refresh_options`

  刷新如下 `AccessToken`：
  - `access_token`
  """
  @spec mini_app_refresh_options(DouYin.client()) :: refresh_options
  def mini_app_refresh_options(client) do
    app_id = client.app_id()
    [{app_id, :access_token, &__MODULE__.refresh_access_token/1}]
  end

  @spec refresh_access_token(DouYin.client()) :: refresh_fun_result
  def refresh_access_token(client) do
    with {:ok, %{status: 200, body: %{"err_no" => 0, "data" => data}}} <-
           DouYin.MiniApp.Credential.get_access_token(client),
         %{"access_token" => access_token, "expires_in" => expires_in} <- data do
      {:ok, access_token, expires_in}
    end
  end
end
