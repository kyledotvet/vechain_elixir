defmodule VeChain.NetworkTest do
  use ExUnit.Case, async: true

  alias VeChain.Network

  doctest VeChain.Network

  describe "get/1" do
    test "returns mainnet configuration" do
      network = Network.get(:mainnet)

      assert network.name == :mainnet
      assert network.chain_tag == 0x4A
      assert is_binary(network.default_node)
      assert String.contains?(network.default_node, "mainnet")
    end

    test "returns testnet configuration" do
      network = Network.get(:testnet)

      assert network.name == :testnet
      assert network.chain_tag == 0x27
      assert is_binary(network.default_node)
      assert String.contains?(network.default_node, "testnet")
    end

    test "returns solo configuration" do
      network = Network.get(:solo)

      assert network.name == :solo
      assert network.chain_tag == 0xA4
      assert network.default_node == "http://localhost:8669"
    end

    test "returns nil for unknown network" do
      assert Network.get(:unknown) == nil
    end
  end

  describe "get!/1" do
    test "returns network configuration" do
      network = Network.get!(:mainnet)

      assert network.name == :mainnet
    end

    test "raises for unknown network" do
      assert_raise ArgumentError, fn ->
        Network.get!(:unknown)
      end
    end
  end

  describe "chain_tag/1" do
    test "returns chain tag for mainnet" do
      assert Network.chain_tag(:mainnet) == 0x4A
    end

    test "returns chain tag for testnet" do
      assert Network.chain_tag(:testnet) == 0x27
    end

    test "returns chain tag for solo" do
      assert Network.chain_tag(:solo) == 0xA4
    end

    test "returns nil for unknown network" do
      assert Network.chain_tag(:unknown) == nil
    end
  end

  describe "default_node/1" do
    test "returns default node URL for mainnet" do
      node = Network.default_node(:mainnet)

      assert is_binary(node)
      assert String.starts_with?(node, "http")
    end

    test "returns default node URL for testnet" do
      node = Network.default_node(:testnet)

      assert is_binary(node)
      assert String.starts_with?(node, "http")
    end

    test "returns localhost for solo" do
      assert Network.default_node(:solo) == "http://localhost:8669"
    end

    test "returns nil for unknown network" do
      assert Network.default_node(:unknown) == nil
    end
  end

  describe "all/0" do
    test "returns all network configurations" do
      networks = Network.all()

      assert is_list(networks)
      assert length(networks) >= 3

      names = Enum.map(networks, & &1.name)
      assert :mainnet in names
      assert :testnet in names
      assert :solo in names
    end

    test "each network has required fields" do
      networks = Network.all()

      for network <- networks do
        assert is_atom(network.name)
        assert is_integer(network.chain_tag)
        assert is_binary(network.default_node)
      end
    end
  end

  describe "valid?/1" do
    test "returns true for valid networks" do
      assert Network.valid?(:mainnet)
      assert Network.valid?(:testnet)
      assert Network.valid?(:solo)
    end

    test "returns false for invalid networks" do
      refute Network.valid?(:unknown)
      refute Network.valid?(:invalid)
      refute Network.valid?(nil)
    end
  end

  describe "chain tags are unique" do
    test "no two networks have the same chain tag" do
      networks = Network.all()
      chain_tags = Enum.map(networks, & &1.chain_tag)

      assert length(chain_tags) == length(Enum.uniq(chain_tags))
    end
  end

  describe "Network struct" do
    test "has all required fields" do
      network = %Network{
        name: :custom,
        chain_tag: 0xFF,
        default_node: "http://custom.node"
      }

      assert network.name == :custom
      assert network.chain_tag == 0xFF
      assert network.default_node == "http://custom.node"
    end
  end
end
