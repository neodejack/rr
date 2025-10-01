defmodule RR.MixProject do
  use Mix.Project

  def project do
    [
      app: :rr,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {RR.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:burrito, "~> 1.4.0"},
      {:req, "~> 0.5.15"},
      {:toml, "~> 0.7.0"}
    ]
  end
end
