defmodule VeChain.Network do
  @moduledoc """
  Network configuration for VeChainThor networks.

  Provides network-specific configuration including chain tags and default
  Thor node URLs for mainnet, testnet, and solo (local) networks.

  ## Networks

    * `:mainnet` - VeChainThor mainnet (chain tag 0x4a)
    * `:testnet` - VeChainThor testnet (chain tag 0x27)
    * `:solo` - Local Thor Solo node (chain tag 0xf6)

  ## Examples

      iex> VeChain.Network.chain_tag(:mainnet)
      0x4a

      iex> VeChain.Network.default_node(:testnet)
      "https://testnet.veblocks.net"

      iex> config = VeChain.Network.get(:mainnet)
      iex> config.name
      :mainnet
  """

  @type t :: %__MODULE__{
          name: :mainnet | :testnet | :solo,
          chain_tag: byte(),
          default_node: String.t()
        }

  defstruct [:name, :chain_tag, :default_node]

  # Network configurations
  defp mainnet do
    %__MODULE__{
      name: :mainnet,
      chain_tag: 0x4A,
      default_node: "https://mainnet.veblocks.net"
    }
  end

  defp testnet do
    %__MODULE__{
      name: :testnet,
      chain_tag: 0x27,
      default_node: "https://testnet.veblocks.net"
    }
  end

  defp solo do
    %__MODULE__{
      name: :solo,
      chain_tag: 0xF6,
      default_node: "http://localhost:8669"
    }
  end

  @doc """
  Gets network configuration.

  ## Parameters

    * `network` - Network name (`:mainnet`, `:testnet`, `:solo`)

  ## Returns

  Network configuration struct.

  ## Examples

      iex> config = VeChain.Network.get(:mainnet)
      iex> config.chain_tag
      0x4a

      iex> config = VeChain.Network.get(:testnet)
      iex> config.default_node
      "https://testnet.veblocks.net"
  """
  @spec get(:mainnet | :testnet | :solo) :: t()
  def get(:mainnet), do: mainnet()
  def get(:testnet), do: testnet()
  def get(:solo), do: solo()

  @doc """
  Gets the chain tag for a network.

  ## Parameters

    * `network` - Network name (`:mainnet`, `:testnet`, `:solo`)

  ## Returns

  Chain tag byte.

  ## Examples

      iex> VeChain.Network.chain_tag(:mainnet)
      0x4a

      iex> VeChain.Network.chain_tag(:testnet)
      0x27

      iex> VeChain.Network.chain_tag(:solo)
      0xf6
  """
  @spec chain_tag(:mainnet | :testnet | :solo) :: byte()
  def chain_tag(network), do: get(network).chain_tag

  @doc """
  Gets the default Thor node URL for a network.

  ## Parameters

    * `network` - Network name (`:mainnet`, `:testnet`, `:solo`)

  ## Returns

  Default Thor node URL as a string.

  ## Examples

      iex> VeChain.Network.default_node(:mainnet)
      "https://mainnet.veblocks.net"

      iex> VeChain.Network.default_node(:testnet)
      "https://testnet.veblocks.net"

      iex> VeChain.Network.default_node(:solo)
      "http://localhost:8669"
  """
  @spec default_node(:mainnet | :testnet | :solo) :: String.t()
  def default_node(network), do: get(network).default_node

  @doc """
  Validates a network identifier.

  ## Parameters

    * `network` - Network name to validate

  ## Returns

  `true` if valid, `false` otherwise.

  ## Examples

      iex> VeChain.Network.valid?(:mainnet)
      true

      iex> VeChain.Network.valid?(:testnet)
      true

      iex> VeChain.Network.valid?(:invalid)
      false
  """
  @spec valid?(atom()) :: boolean()
  def valid?(network) when network in [:mainnet, :testnet, :solo], do: true
  def valid?(_), do: false
end
