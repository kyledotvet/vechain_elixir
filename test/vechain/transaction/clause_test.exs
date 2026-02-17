defmodule Vechain.Transaction.ClauseTest do
  use ExUnit.Case, async: true

  alias VeChain.Transaction.Clause
  alias Ethers.TxData

  describe "ExRLP.Encode implementation" do
    test "encodes Clause struct correctly with no value" do
      clause = %Clause{
        to:
          <<0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90, 0xAB,
            0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78>>,
        value: <<>>,
        data: <<0xDE, 0xAD, 0xBE, 0xEF>>
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
        to:
          <<0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90, 0xAB,
            0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78>>,
        value: <<0x03, 0xE8>>,
        data: <<0xDE, 0xAD, 0xBE, 0xEF>>
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

  describe "parse_clauses/2" do
    test "parses empty clauses list" do
      config = %{clauses: nil}
      opts = []

      result = Clause.parse_clauses(config, opts)

      assert %{clauses: []} = result
    end

    test "parses list of Clause structs" do
      config = %{}
      clause1 = %Clause{to: "0x1234", value: <<1>>, data: <<>>}
      clause2 = %Clause{to: "0x5678", value: <<2>>, data: <<0xAB>>}
      opts = [clauses: [clause1, clause2]]

      result = Clause.parse_clauses(config, opts)

      assert %{clauses: [^clause1, ^clause2]} = result
    end

    test "parses TxData structs in clauses" do
      config = %{}

      tx_data = %TxData{
        default_address: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
        data: <<0xCA, 0xFE, 0xBA, 0xBE>>,
        selector: %ABI.FunctionSelector{state_mutability: :payable}
      }

      opts = [clauses: [tx_data]]

      result = Clause.parse_clauses(config, opts)

      assert %{clauses: [clause]} = result
      assert %Clause{} = clause

      assert clause.to ==
               <<0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB,
                 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD>>

      assert clause.value == <<>>
      assert clause.data == <<0xCA, 0xFE, 0xBA, 0xBE>>
    end

    test "parses tuple of {TxData, value} in clauses" do
      config = %{}

      tx_data = %TxData{
        default_address: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
        data: <<0xCA, 0xFE, 0xBA, 0xBE>>,
        selector: %ABI.FunctionSelector{state_mutability: :payable}
      }

      opts = [clauses: [{tx_data, 5000}]]

      result = Clause.parse_clauses(config, opts)

      assert %{clauses: [clause]} = result
      assert %Clause{} = clause

      assert clause.to ==
               <<0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB,
                 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD>>

      assert clause.value == :binary.encode_unsigned(5000)
      assert clause.data == <<0xCA, 0xFE, 0xBA, 0xBE>>
    end

    test "parses mixed clause types" do
      config = %{}

      clause_struct = %Clause{
        to:
          <<0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90, 0xAB,
            0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78>>,
        value: <<1>>,
        data: <<>>
      }

      tx_data1 = %TxData{
        default_address: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        data: <<0xAA>>,
        selector: %ABI.FunctionSelector{state_mutability: :non_payable}
      }

      tx_data2 = %TxData{
        default_address: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        data: <<0xBB>>,
        selector: %ABI.FunctionSelector{state_mutability: :payable}
      }

      opts = [clauses: [clause_struct, tx_data1, {tx_data2, 1000}]]

      result = Clause.parse_clauses(config, opts)

      assert %{clauses: [c1, c2, c3]} = result
      assert c1 == clause_struct

      assert %Clause{
               to:
                 <<0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
                   0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA>>,
               value: <<>>,
               data: <<0xAA>>
             } = c2

      assert %Clause{
               to:
                 <<0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                   0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB>>,
               value: value,
               data: <<0xBB>>
             } = c3

      assert value == :binary.encode_unsigned(1000)
    end

    test "preserves other config fields" do
      config = %{chain_tag: <<0x4A>>, nonce: <<1, 2, 3>>}

      clause = %Clause{
        to:
          <<0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90, 0xAB,
            0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78>>,
        value: <<1>>,
        data: <<>>
      }

      opts = [clauses: [clause]]

      result = Clause.parse_clauses(config, opts)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == <<1, 2, 3>>
      assert result.clauses == [clause]
    end
  end

  describe "new/1" do
    test "returns Clause struct unchanged" do
      clause = %Clause{
        to:
          <<0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90, 0xAB,
            0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78>>,
        value: <<1>>,
        data: <<>>
      }

      result = Clause.new(clause)

      assert result == clause
    end

    test "converts TxData to Clause for payable function" do
      tx_data = %TxData{
        default_address: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
        data: <<0xDE, 0xAD, 0xBE, 0xEF>>,
        selector: %ABI.FunctionSelector{state_mutability: :payable}
      }

      result = Clause.new(tx_data)

      assert %Clause{} = result

      assert result.to ==
               <<0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB,
                 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD>>

      assert result.value == <<>>
      assert result.data == <<0xDE, 0xAD, 0xBE, 0xEF>>
    end

    test "converts TxData to Clause for non-payable function" do
      tx_data = %TxData{
        default_address: "0x1234567890123456789012345678901234567890",
        data: <<0xAB, 0xCD>>,
        selector: %ABI.FunctionSelector{state_mutability: :non_payable}
      }

      result = Clause.new(tx_data)

      assert %Clause{} = result

      assert result.to ==
               <<0x12, 0x34, 0x56, 0x78, 0x90, 0x12, 0x34, 0x56, 0x78, 0x90, 0x12, 0x34, 0x56,
                 0x78, 0x90, 0x12, 0x34, 0x56, 0x78, 0x90>>

      assert result.value == <<>>
      assert result.data == <<0xAB, 0xCD>>
    end

    test "converts {TxData, value} tuple to Clause" do
      tx_data = %TxData{
        default_address: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
        data: <<0x12, 0x34>>,
        selector: %ABI.FunctionSelector{state_mutability: :payable}
      }

      result = Clause.new({tx_data, 10_000})

      assert %Clause{} = result

      assert result.to ==
               <<0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB,
                 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD>>

      assert result.value == :binary.encode_unsigned(10_000)
      assert result.data == <<0x12, 0x34>>
    end

    test "converts {TxData, value} tuple with zero value" do
      tx_data = %TxData{
        default_address: "0xabcdabcdabcdabcdabcdabcdabcdabcdabcdabcd",
        data: <<0xFF>>,
        selector: %ABI.FunctionSelector{state_mutability: :payable}
      }

      result = Clause.new({tx_data, 0})

      assert %Clause{} = result
      assert result.value == <<>>
    end

    test "raises ArgumentError for invalid clause format with nil" do
      assert_raise ArgumentError, "Invalid clause format: nil", fn ->
        Clause.new(nil)
      end
    end

    test "raises ArgumentError for invalid clause format with string" do
      assert_raise ArgumentError, ~r/Invalid clause format: "invalid"/, fn ->
        Clause.new("invalid")
      end
    end

    test "raises ArgumentError for invalid clause format with number" do
      assert_raise ArgumentError, "Invalid clause format: 123", fn ->
        Clause.new(123)
      end
    end

    test "raises ArgumentError for invalid clause format with map" do
      assert_raise ArgumentError, ~r/Invalid clause format: %\{foo: "bar"\}/, fn ->
        Clause.new(%{foo: "bar"})
      end
    end

    test "raises ArgumentError for invalid clause format with list" do
      assert_raise ArgumentError, ~r/Invalid clause format: \[1, 2, 3\]/, fn ->
        Clause.new([1, 2, 3])
      end
    end
  end

  describe "from_contract_fn/2" do
    test "creates Clause from payable TxData with hex address" do
      tx_data = %TxData{
        default_address: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
        data: <<0xCA, 0xFE, 0xBA, 0xBE>>,
        selector: %ABI.FunctionSelector{state_mutability: :payable}
      }

      clause = Clause.from_contract_fn(tx_data, 5000)

      assert clause.to ==
               <<0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB,
                 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD>>

      assert clause.value == :binary.encode_unsigned(5000)
      assert clause.data == <<0xCA, 0xFE, 0xBA, 0xBE>>
    end

    test "creates Clause from payable TxData with binary address" do
      address =
        <<0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90, 0xAB,
          0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78>>

      tx_data = %TxData{
        default_address: address,
        data: <<0xDE, 0xAD>>,
        selector: %ABI.FunctionSelector{state_mutability: :payable}
      }

      clause = Clause.from_contract_fn(tx_data, 1000)

      assert clause.to == address
      assert clause.value == :binary.encode_unsigned(1000)
      assert clause.data == <<0xDE, 0xAD>>
    end

    test "creates Clause from non-payable TxData" do
      tx_data = %TxData{
        default_address: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
        data: <<0xCA, 0xFE>>,
        selector: %ABI.FunctionSelector{state_mutability: :non_payable}
      }

      clause = Clause.from_contract_fn(tx_data, 5000)

      assert clause.to ==
               <<0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB,
                 0xCD, 0xEF, 0xAB, 0xCD, 0xEF, 0xAB, 0xCD>>

      assert clause.value == <<>>
      assert clause.data == <<0xCA, 0xFE>>
    end

    test "creates Clause from payable TxData with nil address for contract deployment" do
      tx_data = %TxData{
        default_address: nil,
        data: <<0x60, 0x80, 0x60, 0x40>>,
        selector: %ABI.FunctionSelector{state_mutability: :payable}
      }

      clause = Clause.from_contract_fn(tx_data, 0)

      assert clause.to == <<>>
      assert clause.value == <<>>
      assert clause.data == <<0x60, 0x80, 0x60, 0x40>>
    end

    test "creates Clause from non-payable TxData with nil address for contract deployment" do
      tx_data = %TxData{
        default_address: nil,
        data: <<0x60, 0x80, 0x60, 0x40>>,
        selector: %ABI.FunctionSelector{state_mutability: :non_payable}
      }

      clause = Clause.from_contract_fn(tx_data, 0)

      assert clause.to == <<>>
      assert clause.value == <<>>
      assert clause.data == <<0x60, 0x80, 0x60, 0x40>>
    end
  end

  describe "validate_address/2 (via transfer_vet)" do
    test "accepts valid hex address with empty data" do
      clause = Clause.transfer_vet("0x1234567890123456789012345678901234567890", 1000)

      assert clause.to ==
               <<0x12, 0x34, 0x56, 0x78, 0x90, 0x12, 0x34, 0x56, 0x78, 0x90, 0x12, 0x34, 0x56,
                 0x78, 0x90, 0x12, 0x34, 0x56, 0x78, 0x90>>

      assert clause.value == :binary.encode_unsigned(1000)
      assert clause.data == <<>>
    end

    test "accepts valid binary address with empty data" do
      address =
        <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88,
          0x99, 0x00, 0xAA, 0xBB, 0xCC, 0xDD>>

      clause = Clause.transfer_vet(address, 500)

      assert clause.to == address
      assert clause.value == :binary.encode_unsigned(500)
      assert clause.data == <<>>
    end
  end

  describe "validate_address/2 edge cases" do
    test "raises error when address is nil and data is empty" do
      # This should fail because you can't have a transaction with no recipient and no deployment
      assert_raise ArgumentError, "To address cannot be nil for a clause with empty data", fn ->
        tx_data = %TxData{
          default_address: nil,
          data: <<>>,
          selector: %ABI.FunctionSelector{state_mutability: :payable}
        }

        Clause.from_contract_fn(tx_data, 0)
      end
    end

    test "raises error when address is invalid length (too short)" do
      invalid_address = <<0x12, 0x34, 0x56, 0x78>>

      assert_raise ArgumentError, ~r/To address must be a binary 20 bytes/, fn ->
        tx_data = %TxData{
          default_address: invalid_address,
          data: <<0xAB>>,
          selector: %ABI.FunctionSelector{state_mutability: :payable}
        }

        Clause.from_contract_fn(tx_data, 0)
      end
    end

    test "raises error when address is invalid length (too long)" do
      invalid_address =
        <<0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90, 0xAB,
          0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90, 0xAB>>

      assert_raise ArgumentError, ~r/To address must be a binary 20 bytes/, fn ->
        tx_data = %TxData{
          default_address: invalid_address,
          data: <<0xAB>>,
          selector: %ABI.FunctionSelector{state_mutability: :payable}
        }

        Clause.from_contract_fn(tx_data, 0)
      end
    end

    test "raises error for hex address without 0x prefix" do
      assert_raise ArgumentError, ~r/To address must be a binary 20 bytes/, fn ->
        Clause.transfer_vet("1234567890123456789012345678901234567890", 1000)
      end
    end

    test "raises error for hex address that is too short" do
      assert_raise ArgumentError, fn ->
        Clause.transfer_vet("0x1234", 1000)
      end
    end
  end
end
