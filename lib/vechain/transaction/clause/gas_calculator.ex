defmodule VeChain.Transaction.Clause.GasCalculator do
  @moduledoc """
  Gas calculator for transaction clauses. Ref: https://docs.vechain.org/core-concepts/transactions/transaction-calculation
  """
  @gas_base_cost 5_000
  @gas_per_clause 16_000
  @gas_per_contract_creation_clause 48_000
  @gas_per_zero_byte 4
  @gas_per_non_zero_byte 68

  alias VeChain.Transaction.Clause

  @spec calculate_intrinsic_gas([Clause.t()]) :: pos_integer()
  def calculate_intrinsic_gas([]) do
    @gas_base_cost + @gas_per_clause
  end

  def calculate_intrinsic_gas(clauses) do
    Enum.reduce(clauses, @gas_base_cost, fn clause, acc ->
      acc + calc_gas_for_clause(clause)
    end)
  end

  def calc_gas_for_clause(%Clause{to: nil, data: data}) do
    # Contract creation clause
    @gas_per_contract_creation_clause + calculate_data_gas(data)
  end

  def calc_gas_for_clause(%Clause{data: data}) do
    # Regular clause
    @gas_per_clause + calculate_data_gas(data)
  end

  def calculate_data_gas(data, acc \\ 0)
  def calculate_data_gas(<<>>, acc), do: acc

  def calculate_data_gas(<<0, rest::binary>>, acc) do
    calculate_data_gas(rest, acc + @gas_per_zero_byte)
  end

  def calculate_data_gas(<<_non_zero_byte::binary-size(1), rest::binary>>, acc) do
    calculate_data_gas(rest, acc + @gas_per_non_zero_byte)
  end
end
