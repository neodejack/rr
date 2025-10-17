defmodule RR.MixProject do
  use Mix.Project

  def project do
    [
      app: :rr,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {RR.Application, []},
      extra_applications: [:logger, :runtime_tools, :observer]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:burrito, git: "https://github.com/burrito-elixir/burrito.git", branch: "main"},
      {:owl, "~> 0.13"},
      {:req, "~> 0.5.15"},
      {:breeze,
       git: "https://github.com/neodejack/breeze.git", branch: "default-focus-and-terminate/2"},
      {:toml, "~> 0.7.0"}
    ]
  end

  def releases do
    [
      {
        :rr,
        [
          steps: [:assemble, &Burrito.wrap/1],
          burrito: [
            targets: [
              macos: [os: :darwin, cpu: :x86_64],
              macos_arm: [os: :darwin, cpu: :aarch64],
              linux: [os: :linux, cpu: :x86_64],
              linux_arm: [os: :linux, cpu: :aarch64],
              windows: [os: :windows, cpu: :x86_64]
            ]
          ]
        ]
      }
    ]
  end
end
