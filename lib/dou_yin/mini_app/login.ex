defmodule DouYin.MiniApp.Login do
  @moduledoc false

  import Jason.Helpers
  import DouYin.Utils, only: [mini_app_server_doc_link_prefix: 0]

  @type code :: String.t()
  @type anonymous_code :: String.t()

  @doc """
  code2Session -
  [官方文档](#{mini_app_server_doc_link_prefix()}/log-in/code-2-session){:target="_blank"}
    
  为了保障应用的数据安全，只能在开发者服务器使用 AppSecret；开发者服务器不应该把会话密钥下发到小程序，也不应该对外提供这个密钥。如果小程序存在泄露 AppSecret 或会话密钥的问题，字节小程序平台将有可能下架该小程序，并暂停该小程序相关服务。

  通过login接口获取到登录凭证后，开发者可以通过服务器发送请求的方式获取 session_key 和 openId。

  Tip：登录凭证 code，anonymous_code 只能使用一次，非匿名需要 code，非匿名下的 anonymous_code 用于数据同步，匿名需要 anonymous_code。
  """
  @spec code2session(DouYin.client(), code) :: DouYin.response()
  def code2session(client, code) do
    client.post(
      "/apps/v2/jscode2session",
      json_map(
        appid: client.app_id(),
        secret: client.app_secret(),
        code: code
      )
    )
  end

  @spec anonymous_code2session(DouYin.client(), anonymous_code) :: DouYin.response()
  def anonymous_code2session(client, anonymous_code) do
    client.post(
      "/apps/v2/jscode2session",
      json_map(
        appid: client.app_id(),
        secret: client.app_secret(),
        anonymous_code: anonymous_code
      )
    )
  end
end
