defmodule VeChain.Transaction.Steps.SetChainTag do
  @moduledoc """
  Pipeline step to set the chain tag on a transaction.

  The chain tag identifies which VeChainThor network the transaction is for:
    * Mainnet: 0x4a
    * Testnet: 0x27
    * Solo: 0xf6

  If the transaction already has a chain_tag set (via explicit override), this
  step will not modify it. Otherwise, it uses the network configuration.

  ## Examples

      iex> tx = Transaction.new(network: :testnet)
      iex> tx = SetChainTag.call(tx)
      iex> tx.chain_tag
      0x27
  """

  alias VeChain.{Transaction, Network}

  @doc """
  Sets the chain tag if not already present.

  ## Parameters

    * `tx` - Transaction struct
    * `opts` - Options (unused, for pipeline compatibility)

  ## Returns

  Transaction with chain_tag set.
  """
  @spec call(Transaction.t(), keyword()) :: Transaction.t()
  def call(%Transaction{chain_tag: nil, network: network} = tx, _opts) when network != nil do
    chain_tag = Network.chain_tag(network)
    %{tx | chain_tag: chain_tag}
  end

  def call(%Transaction{chain_tag: nil} = tx, _opts) do
    # No network and no chain_tag - default to testnet for safety
    %{tx | chain_tag: Network.chain_tag(:testnet)}
  end

  def call(%Transaction{} = tx, _opts) do
    # Chain tag already set - don't override
    tx
  end
end
