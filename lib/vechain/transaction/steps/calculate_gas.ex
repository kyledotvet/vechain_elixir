defmodule VeChain.Transaction.Steps.CalculateGas do
  @moduledoc """
  Pipeline step to calculate intrinsic gas for a transaction.

  Intrinsic gas is calculated based on:
    * Base transaction: 5,000 gas
    * Per clause: 16,000 gas (regular) or 48,000 gas (contract creation)
    * Data: 4 gas per zero byte, 68 gas per non-zero byte

  If the transaction already has gas set, this step will not override it.

  ## Examples

      iex> tx = Transaction.new()
      iex> |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      iex> tx = CalculateGas.call(tx)
      iex> tx.gas >= 21000
      true
  """

  alias VeChain.{Transaction, Clause}

  @tx_gas 5_000
  @clause_gas 16_000
  @clause_gas_contract_creation 48_000
  @zero_gas 4
  @non_zero_gas 68

  @doc """
  Calculates and sets intrinsic gas if not already present.

  ## Parameters

    * `tx` - Transaction struct
    * `opts` - Options:
      - `:gas` - Override gas value (optional)

  ## Returns

  Transaction with gas set.
  """
  @spec call(Transaction.t(), keyword()) :: Transaction.t()
  def call(%Transaction{gas: gas} = tx, opts) when gas != nil and gas > 0 do
    # Gas already set and valid - don't override unless opts specify
    case Keyword.get(opts, :gas) do
      nil -> tx
      override_gas -> %{tx | gas: override_gas}
    end
  end

  def call(%Transaction{clauses: clauses} = tx, opts) do
    # Calculate intrinsic gas
    intrinsic_gas = calculate_intrinsic_gas(clauses)

    # Allow override from opts
    gas = Keyword.get(opts, :gas, intrinsic_gas)

    %{tx | gas: gas}
  end

  @doc """
  Calculates the intrinsic gas for a list of clauses.

  ## Parameters

    * `clauses` - List of clause structs

  ## Returns

  Total intrinsic gas as an integer.

  ## Examples

      iex> clauses = [Clause.transfer_vet("0x...", 1000)]
      iex> CalculateGas.calculate_intrinsic_gas(clauses)
      21000
  """
  @spec calculate_intrinsic_gas([Clause.t()]) :: non_neg_integer()
  def calculate_intrinsic_gas(clauses) when is_list(clauses) do
    clause_gas = calculate_clause_gas(clauses)
    data_gas = calculate_data_gas(clauses)

    @tx_gas + clause_gas + data_gas
  end

  # ========================================
  # Private Helpers
  # ========================================

  # Calculate gas for all clauses
  defp calculate_clause_gas(clauses) do
    Enum.reduce(clauses, 0, fn clause, acc ->
      base =
        if clause.to == nil do
          # Contract creation (no "to" address)
          @clause_gas_contract_creation
        else
          # Regular transaction/transfer
          @clause_gas
        end

      acc + base
    end)
  end

  # Calculate gas for all data in clauses
  defp calculate_data_gas(clauses) do
    Enum.reduce(clauses, 0, fn clause, acc ->
      {zero_bytes, non_zero_bytes} = count_bytes(clause.data)
      data_cost = zero_bytes * @zero_gas + non_zero_bytes * @non_zero_gas
      acc + data_cost
    end)
  end

  # Count zero and non-zero bytes in binary data
  defp count_bytes(data) when is_binary(data) do
    data
    |> :binary.bin_to_list()
    |> Enum.reduce({0, 0}, fn
      0, {zero, non_zero} -> {zero + 1, non_zero}
      _, {zero, non_zero} -> {zero, non_zero + 1}
    end)
  end

  defp count_bytes(_), do: {0, 0}
end
