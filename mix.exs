defmodule EDA.MixProject do
  use Mix.Project

  @version "0.5.0-beta.2"
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
        plt_add_apps: [:mix, :mnesia],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  def application do
    [
      extra_applications: extra_applications(Mix.env()),
      mod: {EDA.Application, []}
    ]
  end

  # :mnesia is deliberately NOT a runtime dependency of the library: listing it would
  # start Mnesia for every EDA user, including those who never touch
  # EDA.Cache.Adapter.Mnesia. Applications that do use that adapter add :mnesia to their
  # own :extra_applications. As a dependency EDA compiles in :prod, so only EDA's own dev
  # and test environments get it: the suite exercises the adapter, and Dialyzer needs it on
  # the code path to check the calls — an app it cannot find is left out of the PLT.
  defp extra_applications(env) when env in [:dev, :test], do: [:logger, :mnesia]
  defp extra_applications(_env), do: [:logger]

  defp deps do
    [
      # WebSocket client
      {:websockex, "~> 0.4"},

      # HTTP client. 3.x brings hackney 4, which fixes the CVEs in hackney 1.x
      # (EEF-CVE-2026-47069, -47071, -47075, -47076); 2.x is still accepted so that a
      # project pinned to httpoison 2 for another dependency can resolve.
      {:httpoison, "~> 2.0 or ~> 3.0"},

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

      # DAVE (E2EE voice) NIF: precompiled binaries are downloaded at compile time, so a bot
      # needs no Rust toolchain. Rustler is only needed to build the NIF from source.
      {:rustler_precompiled, "~> 0.8"},
      {:rustler, "~> 0.35", optional: true, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["qoyri"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url, "HexDocs" => "https://hexdocs.pm/eda"},
      files:
        ~w(lib native/eda_dave/src native/eda_dave/.cargo native/eda_dave/Cargo.toml native/eda_dave/Cargo.lock checksum-*.exs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
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
          EDA.App,
          EDA.Attachment,
          EDA.AuditLog,
          EDA.AuditLog.Change,
          EDA.AuditLog.Entry,
          EDA.AutoMod,
          EDA.AutoMod.Action,
          EDA.AutoMod.ActionMetadata,
          EDA.AutoMod.TriggerMetadata,
          EDA.Channel,
          EDA.Channel.DM,
          EDA.Channel.Forum,
          EDA.Channel.Thread,
          EDA.Channel.ThreadMember,
          EDA.Channel.Voice,
          EDA.Command,
          EDA.Command.Option,
          EDA.Command.Permissions,
          EDA.Component,
          EDA.Embed,
          EDA.Emoji,
          EDA.Entitlement,
          EDA.Entity,
          EDA.Entity.Changeset,
          EDA.File,
          EDA.ForumTag,
          EDA.Guild,
          EDA.GuildTemplate,
          EDA.Integration,
          EDA.Interaction,
          EDA.Invite,
          EDA.Member,
          EDA.Member.Flags,
          EDA.Message,
          EDA.Modal,
          EDA.Onboarding,
          EDA.Onboarding.Option,
          EDA.Onboarding.Prompt,
          EDA.PermissionOverwrite,
          EDA.Poll,
          EDA.Poll.Answer,
          EDA.Poll.AnswerCount,
          EDA.Presence,
          EDA.Reaction,
          EDA.Role,
          EDA.Role.Colors,
          EDA.ScheduledEvent,
          EDA.SoundboardSound,
          EDA.Sticker,
          EDA.Sticker.Pack,
          EDA.User,
          EDA.User.AvatarDecoration,
          EDA.User.Collectibles,
          EDA.User.DisplayNameStyles,
          EDA.User.Flags,
          EDA.User.Nameplate,
          EDA.User.PrimaryGuild,
          EDA.VoiceState,
          EDA.Webhook
        ],
        Events: ~r/^EDA\.Event/,
        HTTP: ~r/^EDA\.HTTP/
      ]
    ]
  end
end
