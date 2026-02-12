defmodule EDA.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/yourusername/eda"

  def project do
    [
      app: :eda,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "EDA",
      description: "Elixir Discord API - A modern Discord library for Elixir",
      package: package(),
      docs: docs(),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {EDA.Application, []}
    ]
  end

  defp deps do
    [
      # WebSocket client
      {:websockex, "~> 0.4"},

      # HTTP client
      {:httpoison, "~> 2.0"},

      # JSON encoding/decoding
      {:jason, "~> 1.4"},

      # Telemetry for observability
      {:telemetry, "~> 1.0"},

      # XChaCha20-Poly1305 encryption for voice (pure Elixir)
      {:salchicha, "~> 0.5.0"},

      # Documentation
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},

      # Static analysis
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
