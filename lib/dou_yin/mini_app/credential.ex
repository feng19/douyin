defmodule DouYin.MiniApp.Credential do
  @moduledoc false

  import Jason.Helpers
  import DouYin.Utils, only: [mini_app_server_doc_link_prefix: 0]

  @doc """
  获取AccessToken -
  [官方文档](#{mini_app_server_doc_link_prefix()}/interface-request-credential/get-access-token){:target="_blank"}
  """
  @spec get_access_token(DouYin.client()) :: DouYin.response()
  def get_access_token(client) do
    client.post(
      "/apps/v2/token",
      json_map(
        grant_type: "client_credential",
        appid: client.app_id(),
        secret: client.app_secret()
      )
    )
  end
end
