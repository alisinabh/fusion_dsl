defmodule FusionDsl.MixProject do
  use Mix.Project

  @version "0.0.1-dev"

  def project do
    [
      app: :fusion_dsl,
      version: @version,
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),

      # Docs
      name: "FusionDSL",
      source_url: "https://github.com/fusiondsl/fusion_dsl",
      homepage_url: "https://fusiondsl.org",
      description: """
      An idiot proof, easy, scalable and production ready 
      functional domain specific programming language.
      """
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {FusionDsl, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poison, "~> 3.1"},
      {:credo, "~> 0.9.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["test/integration", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      logo: "fusion-dsl-250px.png",
      extra_section: "GUIDES",
      formatters: ["html", "epub"],
      extras: extras()
    ]
  end

  defp extras do
    ["README.md", "guides/packages.md"]
  end

  defp package do
    [
      maintainers: ["Alisina Bahadori"],
      licenses: ["MIT"],
      links: %{
        website: "https://fusiondsl.org",
        github: "https://github.com/fusiondsl/fusion_dsl"
      },
      files: ~w(lib guides LICENSE mix.exs README.md)
    ]
  end
end
