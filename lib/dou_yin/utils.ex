defmodule DouYin.Utils do
  @moduledoc false

  @mini_app_server_doc_link_prefix "https://developer.open-douyin.com/docs/resource/zh-CN/mini-app/develop/server"
  def mini_app_server_doc_link_prefix, do: @mini_app_server_doc_link_prefix

  def now_unix, do: System.system_time(:second)
end
