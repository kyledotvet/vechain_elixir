defmodule VeChain.Transaction.Clause.GasCalculatorTest do
  use ExUnit.Case, async: true

  alias VeChain.Transaction.Clause
  alias VeChain.Transaction.Clause.GasCalculator

  describe "calculate_intrinsic_gas/1" do
    test "with no clauses, returns base gas cost" do
      assert GasCalculator.calculate_intrinsic_gas([]) == 21_000
    end

    test "with single, non-deploy clause, calculates gas correctly" do
      clause = %Clause{to: <<0::160>>, value: <<>>, data: <<>>}
      assert GasCalculator.calculate_intrinsic_gas([clause]) == 21_000
    end

    test "with single, non-deploy clause, with zero data, calculates gas correctly" do
      clause = %Clause{to: <<0::160>>, value: <<>>, data: <<0, 0, 0>>}
      # base + clause cost + 3 zero bytes
      expected_gas = 5_000 + 16_000 + 4 * 3
      assert GasCalculator.calculate_intrinsic_gas([clause]) == expected_gas
    end

    test "with single, non-deploy clause, with non-zero data, calculates gas correctly" do
      clause = %Clause{to: <<0::160>>, value: <<>>, data: <<1, 2, 3>>}
      # base + clause cost + 3 non-zero bytes
      expected_gas = 5_000 + 16_000 + 68 * 3
      assert GasCalculator.calculate_intrinsic_gas([clause]) == expected_gas
    end

    test "with single, non-deploy clause, with mixed data, calculates gas correctly" do
      clause = %Clause{to: <<0::160>>, value: <<>>, data: <<0, 1, 0, 2>>}
      # base + deploy clause cost + 2 zero bytes + 2 non-zero bytes
      expected_gas = 5_000 + 16_000 + 4 * 2 + 68 * 2
      assert GasCalculator.calculate_intrinsic_gas([clause]) == expected_gas
    end

    test "with single, deploy clause, calculates gas correctly" do
      clause = %Clause{to: nil, value: <<>>, data: <<>>}
      # base + deploy clause cost
      expected_gas = 5_000 + 48_000
      assert GasCalculator.calculate_intrinsic_gas([clause]) == expected_gas
    end

    test "with multiple clauses, calculates gas correctly" do
      clause1 = %Clause{to: <<0::160>>, value: <<>>, data: <<0, 1>>}
      clause2 = %Clause{to: nil, value: <<>>, data: <<1, 2, 3>>}
      # base + clause1 cost + clause2 cost
      expected_gas =
        5_000 + (16_000 + 4 + 68) + (48_000 + 68 * 3)

      assert GasCalculator.calculate_intrinsic_gas([clause1, clause2]) == expected_gas
    end
  end
end
