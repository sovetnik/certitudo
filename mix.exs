defmodule Certitudo.MixProject do
  use Mix.Project

  def project do
    [
      app: :certitudo,
      version: "0.1.2",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      dialyzer: [plt_add_apps: [:mix]],
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/sovetnik/certitudo",
      test_coverage: [
        ignore_modules: [
          Certitudo.Coverage.Runtime,
          Mix.Tasks.Certitudo,
          Mix.Tasks.Certitudo.Discrimen,
          Mix.Tasks.Certitudo.Inspectio,
          Mix.Tasks.Certitudo.Lacunae,
          Mix.Tasks.Certitudo.Speculum
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Elixir coverage diffing by code block, not by line number.

    Certitudo snapshots test coverage and compares snapshots block by block,
    separating real coverage changes from ordinary source movement.
    """
  end

  defp package do
    [
      exclude_patterns: [".DS_Store"],
      files: ~w(mix.exs README.md lib examples),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/sovetnik/certitudo"}
    ]
  end
end
