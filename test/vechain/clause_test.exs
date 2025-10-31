defmodule VeChain.ClauseTest do
  use ExUnit.Case, async: true

  alias VeChain.Clause

  doctest VeChain.Clause

  describe "new/1" do
    test "creates clause with defaults" do
      clause = Clause.new()

      assert clause.to == nil
      assert clause.value == 0
      assert clause.data == <<>>
    end

    test "creates clause with specified fields" do
      to = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 20, 84, 252, 123, 51, 100, 255, 237>>
      clause = Clause.new(to: to, value: 1000, data: <<0x12, 0x34>>)

      assert clause.to == to
      assert clause.value == 1000
      assert clause.data == <<0x12, 0x34>>
    end

    test "accepts hex string address and converts to binary" do
      clause = Clause.new(to: "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", value: 1000)

      assert is_binary(clause.to)
      assert byte_size(clause.to) == 20
    end
  end

  describe "transfer_vet/2" do
    test "creates VET transfer clause with binary address" do
      to = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 20, 84, 252, 123, 51, 100, 255, 237>>
      clause = Clause.transfer_vet(to, 1_000_000_000_000_000_000)

      assert clause.to == to
      assert clause.value == 1_000_000_000_000_000_000
      assert clause.data == <<>>
    end

    test "creates VET transfer clause with hex string address" do
      clause = Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000)

      assert is_binary(clause.to)
      assert byte_size(clause.to) == 20
      assert clause.value == 1000
      assert clause.data == <<>>
    end

    test "accepts address without 0x prefix" do
      clause = Clause.transfer_vet("7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000)

      assert is_binary(clause.to)
      assert byte_size(clause.to) == 20
    end
  end

  describe "transfer_vtho/2" do
    test "creates VTHO transfer clause" do
      to = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      amount = 1_000_000_000_000_000_000

      clause = Clause.transfer_vtho(to, amount)

      # Should be calling VTHO contract
      assert clause.to == VeChain.Utils.normalize_address("0x0000000000000000000000000000456E65726779")
      assert clause.value == 0
      assert byte_size(clause.data) > 0

      # Data should start with transfer function selector
      <<selector::binary-size(4), _rest::binary>> = clause.data
      # transfer(address,uint256) = 0xa9059cbb
      assert selector == <<0xa9, 0x05, 0x9c, 0xbb>>
    end

    test "accepts hex string address" do
      clause = Clause.transfer_vtho("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000)

      assert is_binary(clause.to)
      assert byte_size(clause.to) == 20
    end
  end

  describe "call_contract/4" do
    test "creates contract call clause" do
      contract_address = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      abi = [
        %{
          "name" => "balanceOf",
          "type" => "function",
          "inputs" => [%{"type" => "address"}],
          "outputs" => [%{"type" => "uint256"}]
        }
      ]
      function_name = "balanceOf"
      args = ["0x1234567890123456789012345678901234567890"]

      clause = Clause.call_contract(contract_address, abi, function_name, args)

      assert byte_size(clause.to) == 20
      assert clause.value == 0
      assert byte_size(clause.data) > 0
    end

    test "accepts value for payable functions" do
      contract_address = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      abi = [
        %{
          "name" => "deposit",
          "type" => "function",
          "inputs" => [],
          "outputs" => []
        }
      ]

      clause = Clause.call_contract(contract_address, abi, "deposit", [], value: 1000)

      assert clause.value == 1000
    end
  end

  describe "deploy_contract/2" do
    test "creates contract deployment clause" do
      bytecode = "0x608060405234801561001057600080fd5b50"
      abi = []
      args = []

      clause = Clause.deploy_contract(bytecode, abi, args)

      assert clause.to == nil
      assert clause.value == 0
      assert byte_size(clause.data) > 0
    end

    test "includes constructor arguments" do
      bytecode = "0x6080604052"
      abi = [
        %{
          "type" => "constructor",
          "inputs" => [%{"type" => "uint256"}]
        }
      ]
      args = [1000]

      clause = Clause.deploy_contract(bytecode, abi, args)

      assert clause.to == nil
      assert byte_size(clause.data) > byte_size(VeChain.Utils.decode_hex!(bytecode))
    end
  end

  describe "encode/1" do
    test "encodes clause to RLP array" do
      clause = %Clause{
        to: <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 20, 84, 252, 123, 51, 100, 255, 237>>,
        value: 1000,
        data: <<>>
      }

      encoded = Clause.encode(clause)

      assert is_list(encoded)
      assert length(encoded) == 3
      assert Enum.at(encoded, 0) == clause.to
      assert Enum.at(encoded, 1) == clause.value
      assert Enum.at(encoded, 2) == clause.data
    end

    test "encodes nil address as empty binary" do
      clause = %Clause{to: nil, value: 0, data: <<0x12, 0x34>>}

      encoded = Clause.encode(clause)

      assert Enum.at(encoded, 0) == <<>>
    end
  end

  describe "decode/1" do
    test "decodes RLP array to clause" do
      to = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 20, 84, 252, 123, 51, 100, 255, 237>>
      rlp_list = [to, 1000, <<>>]

      {:ok, clause} = Clause.decode(rlp_list)

      assert clause.to == to
      assert clause.value == 1000
      assert clause.data == <<>>
    end

    test "decodes empty address as nil" do
      rlp_list = [<<>>, 0, <<0x12, 0x34>>]

      {:ok, clause} = Clause.decode(rlp_list)

      assert clause.to == nil
      assert clause.value == 0
      assert clause.data == <<0x12, 0x34>>
    end

    test "returns error for invalid format" do
      assert {:error, _} = Clause.decode([1, 2])
      assert {:error, _} = Clause.decode("invalid")
    end
  end
end
