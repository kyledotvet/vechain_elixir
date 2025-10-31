defmodule VeChain.Transaction.Steps.SetBlockRef do
  @moduledoc """
  Pipeline step to set the block reference on a transaction.

  The block reference is an 8-byte value that indicates which block the
  transaction references. It consists of:
    * First 4 bytes: Block height (number)
    * Last 4 bytes: Part of the block ID

  The block reference determines after which block this transaction can be
  included in the blockchain.

  If the transaction already has a block_ref set, this step will not modify it.

  ## Examples

      iex> tx = Transaction.new(network: :testnet)
      iex> client = Thor.client_for(:testnet)
      iex> tx = SetBlockRef.call(tx, client: client)
      iex> byte_size(tx.block_ref)
      8
  """

  alias VeChain.{Transaction, Client.Thor}

  @doc """
  Sets the block reference from the latest block.

  Fetches the latest block from the Thor node and extracts the first 8 bytes
  of the block ID as the block reference.

  ## Parameters

    * `tx` - Transaction struct
    * `opts` - Options:
      - `:client` - Thor client (required if block_ref not set)

  ## Returns

  Transaction with block_ref set.
  """
  @spec call(Transaction.t(), keyword()) :: Transaction.t()
  def call(%Transaction{block_ref: nil} = tx, opts) do
    client = Keyword.get(opts, :client)

    if client == nil do
      raise ArgumentError, "client option is required when block_ref is not set"
    end

    case Thor.get_block(client, "best") do
      {:ok, block} ->
        block_ref = extract_block_ref(block)
        %{tx | block_ref: block_ref}

      {:error, reason} ->
        raise "Failed to get block reference: #{inspect(reason)}"
    end
  end

  def call(%Transaction{} = tx, _opts) do
    # Block ref already set - don't override
    tx
  end

  # ========================================
  # Private Helpers
  # ========================================

  # Extract block reference from block data
  defp extract_block_ref(%{"id" => "0x" <> block_id_hex}) do
    # Decode block ID and take first 8 bytes
    case Base.decode16(block_id_hex, case: :mixed) do
      {:ok, <<block_ref::binary-size(8), _rest::binary>>} ->
        block_ref

      _ ->
        raise "Invalid block ID format"
    end
  end

  defp extract_block_ref(_block) do
    raise "Block ID not found in block data"
  end
end
