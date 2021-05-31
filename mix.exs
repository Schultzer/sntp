defmodule SNTP.Mixfile do
  use Mix.Project

  @version "0.2.1"

  def project do
    [
      app: :sntp,
      version: @version,
      elixir: "~> 1.8",
      name: "SNTP",
      source_url: "https://github.com/schultzer/sntp",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  def application do
    [
      env: [auto_start: false, retreive_every: 24 * 60 * 60 * 1000],
      extra_applications: [:logger],
      mod: {SNTP.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.24", only: [:release, :dev]},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false, optional: true}
    ]
  end

  defp description do
    """
    SNTP v4 client [RFC4330](https://tools.ietf.org/html/rfc4330) for Elixir
    """
  end

  defp package do
    [
      name: :sntp,
      maintainers: ["Benjamin Schultzer"],
      licenses: ~w(MIT),
      links: links(),
      files: ~w(CHANGELOG* README* LICENSE* config lib mix.exs)
    ]
  end

  def docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  def links do
    %{
      "GitHub"    => "https://github.com/schultzer/sntp",
      "Readme"    => "https://github.com/schultzer/sntp/blob/v#{@version}/README.md",
      "Changelog" => "https://github.com/schultzer/sntp/blob/v#{@version}/CHANGELOG.md"
    }
  end

  defp elixirc_paths(:test), do: ~w(lib mix test)
  defp elixirc_paths(:dev), do: ~w(lib mix)
  defp elixirc_paths(_), do: ~w(lib)
end
