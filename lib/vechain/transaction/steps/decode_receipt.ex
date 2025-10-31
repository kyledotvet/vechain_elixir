defmodule VeChain.Transaction.Steps.DecodeReceipt do
  @moduledoc """
  Pipeline step to decode and validate a transaction receipt.

  Parses the receipt from the Thor node and checks for transaction revert.
  If the transaction was reverted, this step will raise an error.

  ## Examples

      iex> tx = Transaction.new(chain_tag: 0x27)
      iex> |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      iex> |> Sign.call(private_key: private_key)
      iex> |> Broadcast.call(client: client)
      iex> |> AwaitReceipt.call(client: client)
      iex> tx = DecodeReceipt.call(tx)
      iex> tx.private[:receipt]["reverted"]
      false
  """

  alias VeChain.Transaction

  @doc """
  Decodes and validates the transaction receipt.

  Checks if the transaction was reverted and raises an error if so.
  Otherwise, returns the transaction unchanged.

  ## Parameters

    * `tx` - Transaction struct (must have receipt in private field)
    * `opts` - Options:
      - `:check_revert` - Whether to raise on revert (default: true)

  ## Returns

  Transaction unchanged if successful.

  ## Raises

  ArgumentError if receipt is not present.
  RuntimeError if transaction was reverted and `:check_revert` is true.
  """
  @spec call(Transaction.t(), keyword()) :: Transaction.t()
  def call(%Transaction{private: private} = tx, opts) do
    receipt = Map.get(private, :receipt)

    if receipt == nil do
      raise ArgumentError, "Receipt must be present before decoding"
    end

    check_revert = Keyword.get(opts, :check_revert, true)

    if check_revert and reverted?(receipt) do
      revert_reason = get_revert_reason(receipt)
      raise "Transaction reverted: #{revert_reason}"
    end

    # Receipt is valid - return transaction unchanged
    tx
  end

  @doc """
  Checks if a receipt indicates the transaction was reverted.

  ## Parameters

    * `receipt` - Receipt map from Thor node

  ## Returns

  Boolean indicating if the transaction was reverted.

  ## Examples

      iex> receipt = %{"reverted" => false}
      iex> DecodeReceipt.reverted?(receipt)
      false

      iex> receipt = %{"reverted" => true}
      iex> DecodeReceipt.reverted?(receipt)
      true
  """
  @spec reverted?(map()) :: boolean()
  def reverted?(%{"reverted" => reverted}) when is_boolean(reverted), do: reverted
  def reverted?(_), do: false

  @doc """
  Extracts the revert reason from a receipt.

  ## Parameters

    * `receipt` - Receipt map from Thor node

  ## Returns

  Revert reason as a string, or a default message.

  ## Examples

      iex> receipt = %{"reverted" => true, "outputs" => [%{"vmError" => "out of gas"}]}
      iex> DecodeReceipt.get_revert_reason(receipt)
      "out of gas"

      iex> receipt = %{"reverted" => true}
      iex> DecodeReceipt.get_revert_reason(receipt)
      "unknown reason"
  """
  @spec get_revert_reason(map()) :: String.t()
  def get_revert_reason(%{"outputs" => outputs}) when is_list(outputs) do
    # Try to find VM error in first output
    case List.first(outputs) do
      %{"vmError" => vm_error} when is_binary(vm_error) and vm_error != "" ->
        vm_error

      _ ->
        "unknown reason"
    end
  end

  def get_revert_reason(_receipt), do: "unknown reason"

  @doc """
  Gets the gas used from a receipt.

  ## Parameters

    * `receipt` - Receipt map from Thor node

  ## Returns

    * `{:ok, gas_used}` - Gas used as integer
    * `{:error, :not_found}` - Gas used field not found

  ## Examples

      iex> receipt = %{"gasUsed" => 21000}
      iex> DecodeReceipt.get_gas_used(receipt)
      {:ok, 21000}
  """
  @spec get_gas_used(map()) :: {:ok, non_neg_integer()} | {:error, :not_found}
  def get_gas_used(%{"gasUsed" => gas_used}) when is_integer(gas_used) do
    {:ok, gas_used}
  end

  def get_gas_used(_receipt), do: {:error, :not_found}

  @doc """
  Gets the transaction ID from a receipt.

  ## Parameters

    * `receipt` - Receipt map from Thor node

  ## Returns

    * `{:ok, tx_id}` - Transaction ID as hex string
    * `{:error, :not_found}` - Transaction ID not found

  ## Examples

      iex> receipt = %{"meta" => %{"txID" => "0xabcd..."}}
      iex> DecodeReceipt.get_tx_id(receipt)
      {:ok, "0xabcd..."}
  """
  @spec get_tx_id(map()) :: {:ok, String.t()} | {:error, :not_found}
  def get_tx_id(%{"meta" => %{"txID" => tx_id}}) when is_binary(tx_id) do
    {:ok, tx_id}
  end

  def get_tx_id(_receipt), do: {:error, :not_found}
end
