defmodule DouYin.MiniApp do
  @moduledoc false

  @base_option_fields [
    :app_id,
    :app_type,
    :sandbox?,
    :app_secret,
    :code_name,
    :storage,
    :requester
  ]
  @default_opts [
    app_type: :mini_app,
    sandbox?: false,
    storage: DouYin.Storage.File
  ]

  defmacro __using__(options \\ []) do
    opts = Macro.prewalk(options, &Macro.expand(&1, __CALLER__))

    Keyword.merge(@default_opts, opts)
    |> Keyword.take(@base_option_fields)
    |> gen_get_functions(__CALLER__.module)
  end

  defp gen_get_functions(default_opts, client) do
    app_id =
      case Keyword.get(default_opts, :app_id) do
        app_id when is_binary(app_id) -> app_id
        _ -> raise ArgumentError, "please set app_id"
      end

    {code_name, default_opts} =
      Keyword.pop_lazy(default_opts, :code_name, fn ->
        client |> to_string() |> String.split(".") |> List.last() |> String.downcase()
      end)

    {requester, default_opts} = Keyword.pop(default_opts, :requester)
    request_funs = gen_request_funs(requester, default_opts)

    base =
      quote do
        def code_name, do: unquote(code_name)
        def get_access_token, do: DouYin.Storage.Cache.get_cache(unquote(app_id), :access_token)
      end

    get_funs =
      Enum.map(default_opts, fn {key, value} ->
        quote do
          def unquote(key)(), do: unquote(value)
        end
      end)

    [base, request_funs | get_funs]
  end

  defp gen_request_funs(nil, default_opts) do
    base_url =
      if Keyword.get(default_opts, :sandbox?) do
        # 沙盒环境域名 
        "https://open-sandbox.douyin.com/api"
      else
        # 线上环境域名 
        "https://developer.toutiao.com/api"
      end

    quote do
      use Tesla, only: [:get, :post]

      if Mix.env() == :test do
        adapter Tesla.Mock
      else
        adapter Tesla.Adapter.Finch,
          name: DouYin.Finch,
          pool_timeout: 5_000,
          receive_timeout: 5_000

        plug Tesla.Middleware.BaseUrl, unquote(base_url)
        plug Tesla.Middleware.Logger
      end

      plug Tesla.Middleware.Retry,
        delay: 500,
        max_retries: 3,
        max_delay: 2_000,
        should_retry: fn
          {:ok, %{status: status}} when status in [400, 500] -> true
          {:ok, _} -> false
          {:error, _} -> true
        end

      plug Tesla.Middleware.JSON
    end
  end

  defp gen_request_funs(requester, _default_opts) do
    quote do
      defdelegate get(url), to: unquote(requester)
      defdelegate get(url, opts), to: unquote(requester)
      defdelegate get(client, url, opts), to: unquote(requester)
      defdelegate post(url, body), to: unquote(requester)
      defdelegate post(url, body, opts), to: unquote(requester)
      defdelegate post(client, url, body, opts), to: unquote(requester)
    end
  end
end
