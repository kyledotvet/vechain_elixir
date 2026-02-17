defmodule VeChain do
  @moduledoc """
  Highest-level convenience API for basic VeChain blockchain interactions.

  This module provides user-friendly functions for common VeChain operations:
  - Transferring VET and VTHO tokens
  - Basic calling of smart contracts
  - Executing transactions with sensible defaults

  All functions accept hex string addresses (with or without "0x" prefix)
  and provide both tuple-returning and bang (!) versions.

  ## Examples

  ### Transfer VET

      VeChain.transfer_vet(
        to: "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
        amount: VeChain.Units.vet(10),
        network: :testnet
      )

  ### Transfer VTHO

  ## Options

  Most functions accept these common options:

  - `:network` - Network to use (`:mainnet`, `:testnet`, `:solo`), defaults to `:testnet`
  - `:chain_tag` - Override network's chain tag (optional)
  - `:block_ref` - Explicit block reference (optional, auto-fetched if not provided)
  - `:expiration` - Transaction expiration in blocks (default: 32)
  - `:gas` - Gas limit (auto-calculated if not provided)
  - `:gas_price_coef` - Gas price coefficient (default: 0)
  - `:depends_on` - Transaction dependency (optional)
  - `:nonce` - Explicit nonce (optional, auto-generated if not provided)
  - `:gas_payer_private_key` - VIP-191 gas payer key for fee delegation (optional)
  - `:await_receipt` - Wait for transaction confirmation (default: true)
  - `:timeout` - Receipt polling timeout in milliseconds (default: 60_000)
  - `:interval` - Receipt polling interval in milliseconds (default: 1_000)

  ## Error Handling

  Functions return `{:ok, result}` on success or `{:error, reason}` on failure.
  Bang versions (!) raise exceptions on errors.

      # Tuple version
      case VeChain.transfer_vet(to: address, amount: amount, private_key: key) do
        {:ok, receipt} -> IO.puts("Success!")
        {:error, reason} -> IO.puts("Error: \#{inspect(reason)}")
      end

      # Bang version
      receipt = VeChain.transfer_vet!(to: address, amount: amount, private_key: key)
  """

  # alias VeChain.Transaction
  # alias VeChain.Transaction.Clause
  # alias VeChain.Configuration
  # alias VeChain.Client.Thor
  # alias Ethers.Types
  # alias VeChain.Contracts.VTHO
  # @spec transfer_vet(Types.t_address(), pos_integer(), keyword()) :: any()
  # def transfer_vet(to, amount, opts \\ []) do
  #   opts
  #   |> Transaction.new()
  #   |> Transaction.append_clause(Clause.transfer_vet(to, amount))
  #   |> Transaction.sign(Configuration.get_private_key(opts, :sender))
  #   |> write(opts)
  # end

  # @spec transfer_vet!(Types.t_address(), pos_integer(), keyword()) :: any()
  # def transfer_vet!(to, amount, opts \\ []) do
  #   transfer_vet(to, amount, opts)
  #   |> case do
  #     {:ok, receipt} -> receipt
  #     {:error, reason} -> raise reason
  #   end
  # end

  # @spec transfer_vtho(keyword()) :: any()
  # def transfer_vtho(opts \\ []) do
  #   opts
  #   |> Transaction.new()
  #   |> Transaction.add_clause(
  #     VTHO.transfer(
  #       Keyword.fetch!(opts, :to),
  #       Keyword.fetch!(opts, :amount)
  #     )
  #   )
  #   |> Transaction.sign(opts)
  #   |> Transaction.execute(opts)
  # end

  # @spec transfer_vtho!(keyword()) :: any()
  # def transfer_vtho!(opts) do
  #   opts
  #   |> transfer_vtho()
  #   |> case do
  #     {:ok, receipt} -> receipt
  #     {:error, reason} -> raise reason
  #   end
  # end

  # TODO: Either use the configured RPC endpoint to directly use the Ethers path for calling read-only functions or implement a similar function in the Thor client using the "Inspect clauses" endpoint (POST /accounts/*)
  # @spec read(Ethers.TxData.t() | Transaction.t()) :: any()
  # def read(%Ethers.TxData{} = tx_data) do
  #   Ethers.call(tx_data)
  # end

  # def read(%{clauses: clauses} = transaction) do
  #   clauses
  #   |> Enum.map(&Clause.to_tx_data/1)
  #   |> Enum.map(&Ethers.call/1)
  # end

  # def write(transaction, opts) do
  #   transaction
  #   |> Transaction.encode(opts)
  #   |> Thor.post_transaction()
  # end
end
