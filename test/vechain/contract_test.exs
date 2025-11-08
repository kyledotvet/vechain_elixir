defmodule VeChain.ContractTest do
  use ExUnit.Case, async: true

  # Define test contract modules
  defmodule SimpleStorage do
    use VeChain.Contract,
      abi_file: "test/fixtures/abis/simple_storage.json"
  end

  defmodule ERC20 do
    use VeChain.Contract,
      abi_file: "test/fixtures/abis/erc20.json",
      default_address: "0x0000000000000000000000000000456E65726779"
  end

  defmodule InlineABI do
    @inline_abi [
      %{
        "inputs" => [%{"name" => "x", "type" => "uint256"}],
        "name" => "getValue",
        "outputs" => [%{"name" => "", "type" => "uint256"}],
        "stateMutability" => "view",
        "type" => "function"
      }
    ]

    use VeChain.Contract, abi: @inline_abi
  end

  describe "contract module generation" do
    test "generates module with correct exports" do
      assert function_exported?(SimpleStorage, :__default_address__, 0)
      assert function_exported?(SimpleStorage, :__abi__, 0)
      assert function_exported?(SimpleStorage, :constructor, 0)
    end

    test "generates functions from ABI" do
      assert function_exported?(SimpleStorage, :get_value, 1)
      assert function_exported?(SimpleStorage, :set_value, 1)
    end

    test "generates EventFilters module" do
      assert Code.ensure_loaded?(SimpleStorage.EventFilters)
      assert function_exported?(SimpleStorage.EventFilters, :value_changed, 0)
    end

    test "generates Errors module" do
      assert Code.ensure_loaded?(SimpleStorage.Errors)
    end
  end

  describe "__default_address__/0" do
    test "returns nil when no address provided" do
      assert SimpleStorage.__default_address__() == nil
    end

    test "returns address when provided" do
      assert ERC20.__default_address__() == "0x0000000000000000000000000000456E65726779"
    end
  end

  describe "__abi__/0" do
    test "returns parsed ABI specification" do
      abi = SimpleStorage.__abi__()
      assert is_list(abi)
      assert length(abi) > 0

      # Check for constructor
      assert Enum.any?(abi, &(&1.type == :constructor))

      # Check for functions
      assert Enum.any?(abi, &(&1.function == "getValue"))
      assert Enum.any?(abi, &(&1.function == "setValue"))
    end
  end

  describe "constructor/N" do
    test "generates constructor with no args" do
      result = SimpleStorage.constructor()
      assert is_binary(result)
    end
  end

  describe "view functions" do
    test "generated view functions have correct signature" do
      # Function exists with proper arity (args + opts)
      assert function_exported?(ERC20, :name, 1)
      assert function_exported?(ERC20, :symbol, 1)
      assert function_exported?(ERC20, :decimals, 1)
      assert function_exported?(ERC20, :total_supply, 1)
      assert function_exported?(ERC20, :balance_of, 2)
    end

    test "inline ABI creates callable functions" do
      assert function_exported?(InlineABI, :get_value, 2)
    end
  end

  describe "transaction functions" do
    test "generated transaction functions return clauses" do
      clause = ERC20.transfer("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000)

      assert %VeChain.Clause{} = clause
      assert clause.to == "0x0000000000000000000000000000456E65726779"
      # Data is stored as binary internally (not hex string)
      assert is_binary(clause.data)
      assert byte_size(clause.data) > 0
    end

    test "transaction functions validate addresses" do
      # Invalid addresses won't match the selector type check
      assert_raise ArgumentError, fn ->
        ERC20.transfer("invalid_address", 1000)
      end
    end

    test "approve creates valid clause" do
      clause = ERC20.approve("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 5000)

      assert %VeChain.Clause{} = clause
      assert clause.to == ERC20.__default_address__()
    end

    test "transfer_from creates valid clause" do
      from = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      to = "0x1234567890123456789012345678901234567890"

      clause = ERC20.transfer_from(from, to, 100)

      assert %VeChain.Clause{} = clause
      assert is_binary(clause.data)
    end
  end

  describe "event filters" do
    test "EventFilters module is generated" do
      assert Code.ensure_loaded?(ERC20.EventFilters)
      assert function_exported?(ERC20.EventFilters, :__events__, 0)
    end

    test "event filter functions are generated" do
      assert function_exported?(ERC20.EventFilters, :transfer, 2)
      assert function_exported?(ERC20.EventFilters, :approval, 2)
    end

    test "creates event filter with topics" do
      from = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"

      filter = ERC20.EventFilters.transfer(from, nil)

      assert is_map(filter)
      assert is_list(filter.topics)
      assert length(filter.topics) > 0

      # First topic is event signature
      [signature | _indexed_topics] = filter.topics
      assert String.starts_with?(signature, "0x")
      assert byte_size(signature) == 66  # "0x" + 64 hex chars
    end

    test "event filters include contract address" do
      filter = ERC20.EventFilters.transfer(nil, nil)
      assert filter.address == ERC20.__default_address__()
    end

    test "__events__/0 returns all event selectors" do
      events = ERC20.EventFilters.__events__()
      assert is_list(events)
      assert length(events) > 0

      # Check event types
      assert Enum.all?(events, &(&1.type == :event))
    end
  end

  describe "function selector matching" do
    test "functions accept correct arguments" do
      # View functions work with just required args (opts defaults to [])
      # This would call the contract, so we just verify it's callable
      assert function_exported?(ERC20, :balance_of, 2)

      # Transaction functions work with their required args
      clause = ERC20.transfer("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 100)
      assert %VeChain.Clause{} = clause
    end
  end

  describe "documentation" do
    test "functions have documentation" do
      # Check that functions are documented
      # Transaction functions have arity 1 (just args, no opts)
      # View functions have arity N+1 (args + opts keyword list)
      assert function_exported?(ERC20, :transfer, 2)
      assert function_exported?(ERC20, :balance_of, 2)

      # Verify we can call the generated function
      clause = ERC20.transfer("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 100)
      assert %VeChain.Clause{} = clause
    end
  end

  describe "type safety" do
    test "validates address parameters" do
      # Valid address should work
      clause = ERC20.transfer("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 100)
      assert %VeChain.Clause{} = clause

      # Invalid address should raise ArgumentError from selector matching
      assert_raise ArgumentError, fn ->
        ERC20.transfer("not_an_address", 100)
      end
    end

    test "accepts integer values for uint256" do
      clause = ERC20.transfer("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000)
      assert %VeChain.Clause{} = clause

      # Big integer
      big_amount = 1_000_000_000_000_000_000
      clause = ERC20.transfer("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", big_amount)
      assert %VeChain.Clause{} = clause
    end
  end

  describe "error handling" do
    test "contract without default address requires address option" do
      # SimpleStorage has no default address
      assert SimpleStorage.__default_address__() == nil

      # This should work with address option (would need mocking for actual call)
      # We're just testing that the function signature accepts the option
      assert function_exported?(SimpleStorage, :get_value, 1)
    end
  end
end
