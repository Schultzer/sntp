defmodule ExSntp.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :ex_sntp,
     version: @version,
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()
     # Hex
     description: description(),
     package: package(),

     #Docs
     name: "SNTP",
     docs: [source_ref: "v#{@version}",
            main: "SNTP",
            canonical: "http://hexdocs.pm/sntp",
            source_url: "https://github.com/schultzer/sntp",
            description: "SNTP client [RFC4330](https://tools.ietf.org/html/rfc4330) for Elixir"]]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, "~> 0.14", only: :dev, runtime: false}]
  end

  defp description do
  """
  SNTP client [RFC4330](https://tools.ietf.org/html/rfc4330) for Elixir
  """
  end

  defp package do
    [name: :sntp,
     maintainers: ["Benjamin Schultzer"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/schultzer/sntp",
              "Docs" => "https://hexdocs.pm/sntp"},
     files: ~w(lib) ++
            ~w(mix.exs README.md LICENSE mix.exs)]
  end
end
