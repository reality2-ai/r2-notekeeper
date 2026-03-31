defmodule Notekeeper.MixProject do
  use Mix.Project

  def project do
    [
      app: :notekeeper,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Notekeeper.Application, []}
    ]
  end

  defp deps do
    [
      {:r2_nif, path: "../../../r2-core/elixir/apps/r2_nif"},
      {:r2_core, path: "../../../r2-core/elixir/apps/r2_core"},
      {:jason, "~> 1.4"}
    ]
  end
end
