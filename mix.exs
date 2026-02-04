defmodule VeChain.MixProject do
  use Mix.Project

  def project do
    [
      app: :vechain,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {VeChain.Application, []}
    ]
  end

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
    ]
  end
end
