defmodule VeChain.Transaction.Steps.Broadcast do
  @moduledoc """
  Pipeline step to broadcast a signed transaction to the blockchain.

  Encodes the transaction to RLP format and POSTs it to a Thor node.
  Returns the transaction ID from the response.

  The transaction must be signed before broadcasting.

  ## Examples

      iex> tx = Transaction.new(chain_tag: 0x27)
      iex> |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      iex> |> Sign.call(private_key: private_key)
      iex> client = Thor.client_for(:testnet)
      iex> tx = Broadcast.call(tx, client: client)
      iex> tx.private[:tx_id]
      "0xabcd..."
  """

  alias VeChain.{Transaction, Client.Thor}

  @doc """
  Broadcasts the signed transaction to the blockchain.

  ## Parameters

    * `tx` - Signed transaction struct
    * `opts` - Options:
      - `:client` - Thor client (required)

  ## Returns

  Transaction with broadcast response stored in `:private` field.

  ## Raises

  ArgumentError if transaction is not signed or client is not provided.
  """
  @spec call(Transaction.t(), keyword()) :: Transaction.t()
  def call(%Transaction{signature: nil} = _tx, _opts) do
    raise ArgumentError, "Transaction must be signed before broadcasting"
  end

  def call(%Transaction{} = tx, opts) do
    client = Keyword.get(opts, :client)

    if client == nil do
      raise ArgumentError, "client option is required for broadcasting"
    end

    # Encode transaction to RLP
    encoded = Transaction.encode(tx)

    # Broadcast to Thor node
    case Thor.post_transaction(client, encoded) do
      {:ok, response} ->
        tx_id = response["id"]

        # Emit telemetry event
        :telemetry.execute(
          [:vechain, :transaction, :broadcast],
          %{},
          %{transaction: tx, tx_id: tx_id}
        )

        # Store response in private field
        private = Map.put(tx.private, :tx_id, tx_id)
        private = Map.put(private, :broadcast_response, response)

        %{tx | private: private}

      {:error, reason} ->
        raise "Failed to broadcast transaction: #{inspect(reason)}"
    end
  end
end
