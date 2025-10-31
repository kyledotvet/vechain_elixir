defmodule VeChain.Transaction.Steps.AwaitReceipt do
  @moduledoc """
  Pipeline step to wait for a transaction receipt.

  Polls the Thor node until the transaction is confirmed (included in a block)
  or a timeout is reached.

  ## Options

    * `:timeout` - Maximum time to wait in milliseconds (default: 30_000)
    * `:interval` - Polling interval in milliseconds (default: 1_000)

  ## Examples

      iex> tx = Transaction.new(chain_tag: 0x27)
      iex> |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      iex> |> Sign.call(private_key: private_key)
      iex> |> Broadcast.call(client: client)
      iex> tx = AwaitReceipt.call(tx, client: client, timeout: 60_000)
      iex> tx.private[:receipt]
      %{"reverted" => false, ...}
  """

  alias VeChain.{Transaction, Client.Thor}

  @default_timeout 30_000
  @default_interval 1_000

  @doc """
  Waits for the transaction receipt.

  Polls the Thor node at regular intervals until the receipt is available
  or the timeout is reached.

  ## Parameters

    * `tx` - Transaction struct (must have been broadcast)
    * `opts` - Options:
      - `:client` - Thor client (required)
      - `:timeout` - Maximum wait time in ms (default: 30,000)
      - `:interval` - Polling interval in ms (default: 1,000)

  ## Returns

  Transaction with receipt stored in `:private` field.

  ## Raises

  ArgumentError if transaction has not been broadcast or client is not provided.
  RuntimeError if timeout is reached without receiving a receipt.
  """
  @spec call(Transaction.t(), keyword()) :: Transaction.t()
  def call(%Transaction{private: private} = tx, opts) do
    tx_id = Map.get(private, :tx_id)

    if tx_id == nil do
      raise ArgumentError, "Transaction must be broadcast before awaiting receipt"
    end

    client = Keyword.get(opts, :client)

    if client == nil do
      raise ArgumentError, "client option is required for awaiting receipt"
    end

    timeout = Keyword.get(opts, :timeout, @default_timeout)
    interval = Keyword.get(opts, :interval, @default_interval)

    # Poll for receipt
    case poll_for_receipt(client, tx_id, timeout, interval) do
      {:ok, receipt} ->
        # Emit telemetry event
        :telemetry.execute(
          [:vechain, :transaction, :confirmed],
          %{},
          %{transaction: tx, receipt: receipt}
        )

        # Store receipt in private field
        private = Map.put(tx.private, :receipt, receipt)
        %{tx | private: private}

      {:error, :timeout} ->
        raise "Timeout waiting for transaction receipt after #{timeout}ms"

      {:error, reason} ->
        raise "Failed to get transaction receipt: #{inspect(reason)}"
    end
  end

  # ========================================
  # Private Helpers
  # ========================================

  # Poll for receipt until available or timeout
  defp poll_for_receipt(client, tx_id, timeout, interval) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_poll(client, tx_id, deadline, interval)
  end

  defp do_poll(client, tx_id, deadline, interval) do
    now = System.monotonic_time(:millisecond)

    if now >= deadline do
      {:error, :timeout}
    else
      case Thor.get_transaction_receipt(client, tx_id) do
        {:ok, nil} ->
          # Transaction still pending - sleep and retry
          Process.sleep(interval)
          do_poll(client, tx_id, deadline, interval)

        {:ok, receipt} ->
          # Receipt available
          {:ok, receipt}

        {:error, reason} ->
          # Error fetching receipt
          {:error, reason}
      end
    end
  end
end
