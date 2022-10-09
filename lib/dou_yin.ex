defmodule DouYin do
  @moduledoc """
  DouYin SDK for Elixir

  ## 定义 `Client` 模块

  ### 小程序

      defmodule YourApp.AppCodeName do
        @moduledoc "CodeName"
        use DouYin.MiniApp,
          app_id: "app_id",
          app_secret: "app_secret"
      end

  ## 参数说明

  请看 `t:options/0`

  ## 接口调用

    `DouYin.MiniApp.Login.code2session(YourApp.AppCodeName, code)`
  """

  @typedoc "公众号/小程序 应用id"
  @type app_id :: String.t()
  @typedoc "公众号/小程序 应用代码"
  @type code_name :: String.t()
  @typedoc "应用秘钥"
  @type app_secret :: String.t()

  @typedoc """
  OpenID 用户的标识，对当前应用唯一ID

  加密后的微信号，每个用户对每个应用的 `OpenID` 是唯一的。对于不同应用，同一用户的 `OpenID` 不同
  """
  @type openid :: String.t()
  @type openid_list :: [openid]

  @typedoc """
  UnionID 不同应用下的唯一ID

  同一用户，对同一个开放平台下的不同应用，`UnionID` 是相同的
  """
  @type unionid :: String.t()

  @typedoc "是否是沙盒应用"
  @type sandbox? :: boolean
  @typedoc "错误码"
  @type err_code :: non_neg_integer
  @typedoc "错误信息"
  @type err_msg :: String.t()
  @type url :: String.t()

  @typedoc """
  参数

  ## 参数说明

  - `app_id`: `t:app_id/0` - 必填
  - `code_name`: `t:code_name/0`, 如不指定，默认为模块名最后一个名称的全小写格式
  - `storage`: `t:DouYin.Storage.Adapter.t()`
  - `app_secret`: `t:app_secret/0`
  - `requester`: 请求客户端 - `t:module/0`
  - `sandbox?`: `t:sandbox?/0`

  ## 默认参数:

  - `storage`: `DouYin.Storage.File`
  - `requester`: nil
  - `sandbox?`: false
  """
  @type options :: [
          storage: DouYin.Storage.Adapter.t(),
          app_id: app_id,
          appsecret: app_secret,
          requester: module,
          sandbox?: sandbox?
        ]
  @type client :: module()
  @type requester :: module()
  @type response :: Tesla.Env.result()

  @doc """
  通过 `app_id` 或者 `code_name` 获取 `client`
  """
  @spec get_client(app_id | code_name) :: nil | client
  defdelegate get_client(app_flag), to: DouYin.Storage.Cache, as: :search_client

  @doc "动态构建 client"
  @spec build_client(:mini_app, client, options) :: {:ok, client}
  def build_client(:mini_app, client, options) do
    with {:module, module, _binary, _term} <-
           Module.create(
             client,
             quote do
               @moduledoc false
               use DouYin.MiniApp, unquote(Macro.escape(options))
             end,
             Macro.Env.location(__ENV__)
           ) do
      {:ok, module}
    end
  end

  def refresher do
    Application.get_env(:douyin, :refresher, DouYin.Refresher.Default)
  end

  def add_to_refresher(client, options \\ %{}) do
    m = refresher()
    m.add(client, options)
  end
end
