defmodule EDA.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/qoyri/EDA"

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
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

      # HTTP testing
      {:bypass, "~> 2.1", only: :test},

      # Rustler for DAVE (E2EE voice) NIF — optional, only needed if dave: true
      {:rustler, "~> 0.35", optional: true, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["qoyri"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url, "HexDocs" => "https://hexdocs.pm/eda"},
      files:
        ~w(lib native/eda_dave/src native/eda_dave/Cargo.toml native/eda_dave/Cargo.lock .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        Core: [EDA, EDA.Consumer, EDA.Error, EDA.Snowflake, EDA.Paginator, EDA.Permission],
        API: ~r/^EDA\.API\./,
        Cache: ~r/^EDA\.Cache/,
        Gateway: ~r/^EDA\.Gateway\./,
        Voice: ~r/^EDA\.Voice/,
        Entities: [
          EDA.Activity,
          EDA.Attachment,
          EDA.AuditLog,
          EDA.AuditLog.Change,
          EDA.AuditLog.Entry,
          EDA.AutoMod,
          EDA.AutoMod.Action,
          EDA.AutoMod.ActionMetadata,
          EDA.AutoMod.TriggerMetadata,
          EDA.Channel,
          EDA.Command,
          EDA.Command.Option,
          EDA.Component,
          EDA.Embed,
          EDA.Emoji,
          EDA.Entity,
          EDA.Entity.Changeset,
          EDA.File,
          EDA.ForumTag,
          EDA.Guild,
          EDA.GuildTemplate,
          EDA.Interaction,
          EDA.Invite,
          EDA.Member,
          EDA.Message,
          EDA.Modal,
          EDA.PermissionOverwrite,
          EDA.Poll,
          EDA.Poll.Answer,
          EDA.Poll.AnswerCount,
          EDA.Presence,
          EDA.Reaction,
          EDA.Role,
          EDA.Sticker,
          EDA.Sticker.Pack,
          EDA.User,
          EDA.VoiceState,
          EDA.Webhook
        ],
        Events: ~r/^EDA\.Event/,
        HTTP: ~r/^EDA\.HTTP/
      ]
    ]
  end
end
