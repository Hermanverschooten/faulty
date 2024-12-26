defmodule Faulty.MixProject do
  use Mix.Project

  @source_url "https://github.com/Hermanverschooten/faulty"
  @version "0.1.1"

  def project do
    [
      app: :faulty,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description: "Error tracking for your application",

      # Docs
      name: "Faulty",
      source_url: @source_url,
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Faulty.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:plug, "~> 1.16"},
      {:ecto, "~> 3.11"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:igniter, "~> 0.5", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "Github" => @source_url,
        "Changelog" => "#{@source_url}/blob/v#{@version}/CHANGELOG.md"
      },
      maintainers: [
        "Herman verschooten"
      ],
      files: [
        "lib",
        ".formatter.exs",
        "README.md",
        "LICENSE",
        "mix.exs"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
