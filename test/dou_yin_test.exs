defmodule DouYinTest do
  use ExUnit.Case
  doctest DouYin
  alias DouYin.MiniApp01

  test "Auto generate functions(MiniApp01)" do
    assert MiniApp01.app_id() == "app_id"
    assert MiniApp01.app_secret() == "app_secret"
    assert MiniApp01.code_name() == "miniapp01"
    assert MiniApp01.storage() == DouYin.Storage.File
    assert MiniApp01.sandbox?() == false

    assert true = Enum.all?(1..3, &function_exported?(MiniApp01, :get, &1))
    assert true = Enum.all?(2..4, &function_exported?(MiniApp01, :post, &1))
  end
end
