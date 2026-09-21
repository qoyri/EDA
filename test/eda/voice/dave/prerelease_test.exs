defmodule EDA.Voice.Dave.PrereleaseTest do
  @moduledoc """
  A beta or release candidate of EDA must download the precompiled DAVE NIF like a release does.

  rustler_precompiled forces a build from source for a pre-release version — but only one whose
  pre-release part contains `dev`. `0.5.0-beta.1` and `0.5.0-rc.1` download; `0.5.0-dev` would make
  every consumer without Rust lose voice. Confirmed end to end on 2026-09-21 with a Rust-free
  consumer project: the beta fetched `v0.5.0-beta.1/libeda_dave-v0.5.0-beta.1-...`, the `-dev`
  version fell back to the stubs. This pins the rule so that a rustler_precompiled upgrade
  changing it fails here rather than in a published package.
  """

  use ExUnit.Case, async: true

  defp force_build?(version) do
    RustlerPrecompiled.Config.new(
      otp_app: :eda,
      module: EDA.Voice.Dave.Native,
      crate: "eda_dave",
      base_url: "https://github.com/qoyri/EDA/releases/download/v#{version}",
      version: version,
      force_build: false,
      nif_versions: ["2.15"]
    ).force_build?
  end

  for version <- ["0.5.0", "0.5.0-beta.1", "0.5.0-beta.2", "0.5.0-rc.1"] do
    test "#{version} downloads the precompiled NIF" do
      refute force_build?(unquote(version))
    end
  end

  test "a -dev version would build from source, so it must never be published" do
    assert force_build?("0.5.0-dev")
  end
end
