defmodule PhoenixIconify.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/dannote/phoenix_iconify"

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
      {:iconify, iconify_dep()},
      {:phoenix_live_view, "~> 0.20 or ~> 1.0"},
      {:req, "~> 0.5"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  # Use path dependency for local dev, Hex for published version
  defp iconify_dep do
    if path = System.get_env("ICONIFY_PATH") do
      [path: path]
    else
      "~> 0.1.0"
    end
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
