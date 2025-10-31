defmodule VeChain.Integration.TransferTest do
  use ExUnit.Case

  alias VeChain.{Transaction, Clause, Units, Client}

  @moduletag :integration

  # Test private key - DO NOT use in production
  # This is a well-known test key for VeChain testnet
  @test_private_key Base.decode16!(
                      "7582BE841CA040AA940FFF6C05773129E135623690C06DBE3F7E014706FDDADF",
                      case: :mixed
                    )

  @test_recipient "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"

  describe "VET transfer on testnet" do
    @tag timeout: 60_000
    test "transfers VET using high-level API" do
      {:ok, receipt} =
        VeChain.transfer_vet(
          to: @test_recipient,
          amount: Units.vet(0.001),
          private_key: @test_private_key,
          network: :testnet
        )

      assert receipt["reverted"] == false
      assert is_binary(receipt["meta"]["txID"])
      assert String.starts_with?(receipt["meta"]["txID"], "0x")
      assert is_integer(receipt["gasUsed"])
      assert receipt["gasUsed"] > 0
    end

    @tag timeout: 60_000
    test "transfers VET using mid-level API" do
      {:ok, receipt} =
        Transaction.new(network: :testnet)
        |> Transaction.add_clause(Clause.transfer_vet(@test_recipient, Units.vet(0.001)))
        |> Transaction.run()
        |> Transaction.sign(@test_private_key)
        |> Transaction.broadcast()
        |> Transaction.await_receipt()

      assert receipt["reverted"] == false
      assert is_binary(receipt["meta"]["txID"])
    end
  end

  describe "VTHO transfer on testnet" do
    @tag timeout: 60_000
    test "transfers VTHO using high-level API" do
      {:ok, receipt} =
        VeChain.transfer_vtho(
          to: @test_recipient,
          amount: Units.vtho(1),
          private_key: @test_private_key,
          network: :testnet
        )

      assert receipt["reverted"] == false
      assert is_binary(receipt["meta"]["txID"])
    end
  end

  describe "multi-clause transaction on testnet" do
    @tag timeout: 60_000
    test "executes multiple transfers atomically" do
      recipient1 = @test_recipient
      recipient2 = "0x1234567890123456789012345678901234567890"

      {:ok, receipt} =
        Transaction.new(network: :testnet)
        |> Transaction.add_clause(Clause.transfer_vet(recipient1, Units.vet(0.001)))
        |> Transaction.add_clause(Clause.transfer_vet(recipient2, Units.vet(0.001)))
        |> Transaction.run()
        |> Transaction.sign(@test_private_key)
        |> Transaction.broadcast()
        |> Transaction.await_receipt()

      assert receipt["reverted"] == false
      assert length(receipt["outputs"]) == 2
    end

    @tag timeout: 60_000
    test "all clauses revert if one fails (atomicity)" do
      recipient = @test_recipient

      # Create transaction with insufficient gas
      # This should cause all clauses to revert
      result =
        Transaction.new(network: :testnet)
        |> Transaction.add_clause(Clause.transfer_vet(recipient, Units.vet(0.001)))
        |> Transaction.add_clause(Clause.transfer_vet(recipient, Units.vet(0.001)))
        |> Transaction.put_gas(15000)
        # Intentionally too low
        |> Transaction.run(skip: [:calculate_gas])
        |> Transaction.sign(@test_private_key)
        |> Transaction.broadcast()
        |> Transaction.await_receipt()

      case result do
        {:ok, receipt} ->
          # If it goes through, it should be reverted
          assert receipt["reverted"] == true

        {:error, _reason} ->
          # Or it might fail during broadcast
          assert true
      end
    end
  end

  describe "contract interaction on testnet" do
    @tag timeout: 60_000
    test "calls VTHO balance_of" do
      address = @test_recipient
      client = Client.Thor.new(network: :testnet)

      {:ok, balance} = VeChain.Contracts.VTHO.balance_of(client, address)

      assert is_integer(balance)
      assert balance >= 0
    end

    @tag timeout: 60_000
    test "calls VTHO total_supply" do
      client = Client.Thor.new(network: :testnet)

      {:ok, total_supply} = VeChain.Contracts.VTHO.total_supply(client)

      assert is_integer(total_supply)
      assert total_supply > 0
    end
  end

  describe "transaction status checking" do
    @tag timeout: 60_000
    test "polls for transaction receipt" do
      {:ok, tx_result} =
        Transaction.new(network: :testnet)
        |> Transaction.add_clause(Clause.transfer_vet(@test_recipient, Units.vet(0.001)))
        |> Transaction.run()
        |> Transaction.sign(@test_private_key)
        |> Transaction.broadcast()

      tx_id = Transaction.get_transaction_id(tx_result)
      assert is_binary(tx_id)

      client = Client.Thor.new(network: :testnet)

      # Poll for receipt
      receipt =
        Stream.interval(2000)
        |> Stream.take(15)
        |> Enum.find_value(fn _ ->
          case Client.Thor.get_transaction_receipt(client, tx_id) do
            {:ok, nil} -> nil
            {:ok, receipt} -> receipt
            {:error, _} -> nil
          end
        end)

      assert receipt != nil
      assert receipt["meta"]["txID"] == tx_id
    end
  end

  describe "error handling" do
    @tag timeout: 30_000
    test "handles insufficient VET balance" do
      # Try to send more VET than available
      result =
        VeChain.transfer_vet(
          to: @test_recipient,
          amount: Units.vet(1_000_000),
          # Unrealistic amount
          private_key: @test_private_key,
          network: :testnet
        )

      case result do
        {:error, _reason} ->
          # Should fail before or during broadcast
          assert true

        {:ok, receipt} ->
          # Or should revert
          assert receipt["reverted"] == true
      end
    end

    @tag timeout: 30_000
    test "handles invalid recipient address" do
      assert_raise VeChain.Error.InvalidAddress, fn ->
        VeChain.transfer_vet(
          to: "invalid_address",
          amount: Units.vet(0.001),
          private_key: @test_private_key,
          network: :testnet
        )
      end
    end
  end

  describe "transaction display formatting" do
    @tag timeout: 60_000
    test "formats transaction fields correctly" do
      {:ok, receipt} =
        VeChain.transfer_vet(
          to: @test_recipient,
          amount: Units.vet(0.001),
          private_key: @test_private_key,
          network: :testnet
        )

      tx_id = receipt["meta"]["txID"]

      # Transaction ID should be lowercase hex with 0x prefix
      assert String.starts_with?(tx_id, "0x")
      assert String.length(tx_id) == 66
      # 0x + 64 hex chars
      assert String.downcase(tx_id) == tx_id

      # Block ID should be lowercase hex with 0x prefix
      block_id = receipt["meta"]["blockID"]
      assert String.starts_with?(block_id, "0x")
      assert String.downcase(block_id) == block_id
    end
  end
end
