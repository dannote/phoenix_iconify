defmodule PhoenixIconify.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/TODO/phoenix_iconify"

  def project do
    [
      app: :phoenix_iconify,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "PhoenixIconify",
      description: "Phoenix components for Iconify icons with compile-time discovery"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:iconify, path: "../iconify"},
      {:phoenix_live_view, "~> 0.20 or ~> 1.0"},
      {:req, "~> 0.5"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib priv mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
