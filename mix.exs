defmodule DouYin.MixProject do
  use Mix.Project

  def project do
    [
      app: :douyin,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {DouYin.Application, []}
    ]
  end

  defp deps do
    [
      {:tesla, "~> 1.4"},
      {:finch, "~> 0.13"},
      {:jason, "~> 1.4"}
    ]
  end
end
