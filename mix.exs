defmodule VeChain.MixProject do
  use Mix.Project

  @version "0.0.1"
  @source_url "https://github.com/kyledotvet/vechain_elixir"

  def project do
    [
      app: :vechain,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      name: "VeChain",
      source_url: @source_url,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      description: "VeChainThor blockchain client for Elixir",
      package: package(),
      docs: docs(),
      dialyzer: dialyzer()
      # usage_rules: usage_rules()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ethereumex],
      mod: {VeChain.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ["lib", "priv", "mix.exs", "README*", "LICENSE*", "CHANGELOG*"]
    ]
  end

  defp docs do
    source_ref =
      if String.ends_with?(@version, "-dev") do
        "main"
      else
        "v#{@version}"
      end

    [
      main: "readme",
      extras: [
        "README.md": [title: "Introduction"],
        "CHANGELOG.md": [title: "Changelog"]
        # "guides/configuration.md": [title: "Configuration"],
        # "guides/contracts.md": [title: "Contracts"],
        # "guides/transactions.md": [title: "Transactions"]
      ],
      source_url: @source_url,
      source_ref: source_ref,
      # groups_for_modules: [
      #   Client: [
      #     ~r/^VeChain\.Client\.[A-Za-z0-9.]+$/
      #   ],
      #   Contracts: [
      #     ~r/^VeChain\.Contracts\.[A-Za-z0-9.]+$/
      #   ]
      # ],
      markdown_processor: {ExDoc.Markdown.Earmark, footnotes: true}
    ]
  end

  def dialyzer do
    [flags: [:error_handling, :extra_return, :underspecs, :unknown, :unmatched_returns]]
  end

  # defp usage_rules do
  #   [
  #     file: "CLAUDE.md",
  #     usage_rules: ["usage_rules:all"],
  #     skills: [
  #       location: ".claude/skills"
  #     ]
  #   ]
  # end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:blake2, "~> 1.0"},
      {:ethers, "~> 0.6.10"},
      {:ex_abi, "~> 0.8.3"},
      {:ex_keccak, "~> 0.7.8"},
      {:ex_rlp, "~> 0.6.0"},
      {:ex_secp256k1, "~> 0.7"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},

      # Dev/Test
      {:stream_data, "~> 1.2", only: [:dev, :test]},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
      # {:usage_rules, "~> 1.1.0", only: [:dev]}
    ]
  end
end
