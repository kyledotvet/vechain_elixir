defmodule Vechain.Transaction.ClauseTest do
  use ExUnit.Case, async: true

  alias VeChain.Transaction.Clause
  alias Ethers.TxData

  describe "ExRLP.Encode implementation" do
    test "encodes Clause struct correctly with no value" do
      clause = %Clause{
        to: "0x1234567890abcdef1234567890abcdef12345678",
        value: 0,
        data: "0xdeadbeef"
      }

      encoded = ExRLP.encode(clause)

      expected_rlp_list = [
        <<0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90, 0xAB,
          0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78>>,
        <<>>,
        <<0xDE, 0xAD, 0xBE, 0xEF>>
      ]

      assert encoded == ExRLP.encode(expected_rlp_list)
    end

    test "encodes Clause struct correctly with non-zero value" do
      clause = %Clause{
        to: "0x1234567890abcdef1234567890abcdef12345678",
        value: 1000,
        data: "0xdeadbeef"
      }

      encoded = ExRLP.encode(clause)

      expected_rlp_list = [
        <<0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90, 0xAB,
          0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78>>,
        <<0x03, 0xE8>>,
        <<0xDE, 0xAD, 0xBE, 0xEF>>
      ]

      assert encoded == ExRLP.encode(expected_rlp_list)
    end
  end

  describe "from_contract_fn/2" do
    test "creates Clause from payable TxData" do
      tx_data = %TxData{
        default_address: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
        data: "cafebabe",
        selector: %ABI.FunctionSelector{state_mutability: :payable}
      }

      clause = Clause.from_contract_fn(tx_data, 5000)

      assert clause.to == "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"
      assert clause.value == 5000
      assert clause.data == "0xcafebabe"
    end

    test "creates Clause from non-payable TxData" do
      tx_data = %TxData{
        default_address: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
        data: "cafebabe",
        selector: %ABI.FunctionSelector{state_mutability: :non_payable}
      }

      clause = Clause.from_contract_fn(tx_data, 5000)

      assert clause.to == "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"
      assert clause.value == 0
      assert clause.data == "0xcafebabe"
    end
  end
end
