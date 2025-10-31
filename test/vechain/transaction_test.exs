defmodule VeChain.TransactionTest do
  use ExUnit.Case, async: true
  # use ExUnitProperties

  alias VeChain.{Transaction, Clause, Reserved, Utils}

  doctest VeChain.Transaction

  describe "new/1" do
    test "creates transaction with defaults" do
      tx = Transaction.new()

      assert tx.chain_tag == nil
      assert tx.block_ref == nil
      assert tx.expiration == 32
      assert tx.clauses == []
      assert tx.gas_price_coef == 0
      assert tx.gas == nil
      assert tx.depends_on == nil
      assert tx.nonce == nil
      assert %Reserved{} = tx.reserved
      assert tx.signature == nil
    end

    test "creates transaction with specified fields" do
      tx =
        Transaction.new(
          chain_tag: 0x27,
          expiration: 64,
          gas: 21000
        )

      assert tx.chain_tag == 0x27
      assert tx.expiration == 64
      assert tx.gas == 21000
    end

    test "creates transaction with network" do
      tx = Transaction.new(network: :testnet)

      assert tx.network == :testnet
    end
  end

  describe "add_clause/2" do
    test "adds clause to transaction" do
      clause = Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000)
      tx = Transaction.new() |> Transaction.add_clause(clause)

      assert length(tx.clauses) == 1
      assert hd(tx.clauses) == clause
    end

    test "adds multiple clauses" do
      clause1 = Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000)
      clause2 = Clause.transfer_vet("0x1234567890123456789012345678901234567890", 2000)

      tx =
        Transaction.new()
        |> Transaction.add_clause(clause1)
        |> Transaction.add_clause(clause2)

      assert length(tx.clauses) == 2
      assert Enum.at(tx.clauses, 0) == clause1
      assert Enum.at(tx.clauses, 1) == clause2
    end

    test "maintains clause order" do
      clauses = for i <- 1..5, do: Clause.new(value: i)

      tx = Enum.reduce(clauses, Transaction.new(), &Transaction.add_clause(&2, &1))

      assert tx.clauses == clauses
    end
  end

  describe "put_chain_tag/2" do
    test "sets chain tag" do
      tx = Transaction.new() |> Transaction.put_chain_tag(0x4A)

      assert tx.chain_tag == 0x4A
    end

    test "overwrites existing chain tag" do
      tx =
        Transaction.new()
        |> Transaction.put_chain_tag(0x27)
        |> Transaction.put_chain_tag(0x4A)

      assert tx.chain_tag == 0x4A
    end
  end

  describe "put_block_ref/2" do
    test "sets block ref" do
      block_ref = <<0, 255, 236, 184, 170, 187, 204, 221>>
      tx = Transaction.new() |> Transaction.put_block_ref(block_ref)

      assert tx.block_ref == block_ref
    end

    test "validates block ref is 8 bytes" do
      assert_raise ArgumentError, fn ->
        Transaction.new() |> Transaction.put_block_ref(<<1, 2, 3>>)
      end
    end
  end

  describe "put_expiration/2" do
    test "sets expiration" do
      tx = Transaction.new() |> Transaction.put_expiration(100)

      assert tx.expiration == 100
    end

    test "accepts valid expiration values" do
      tx = Transaction.new() |> Transaction.put_expiration(1)
      assert tx.expiration == 1

      tx = Transaction.new() |> Transaction.put_expiration(2_147_483_647)
      assert tx.expiration == 2_147_483_647
    end
  end

  describe "put_gas/2" do
    test "sets gas" do
      tx = Transaction.new() |> Transaction.put_gas(21000)

      assert tx.gas == 21000
    end
  end

  describe "put_gas_price_coef/2" do
    test "sets gas price coefficient" do
      tx = Transaction.new() |> Transaction.put_gas_price_coef(128)

      assert tx.gas_price_coef == 128
    end

    test "accepts values 0-255" do
      tx = Transaction.new() |> Transaction.put_gas_price_coef(0)
      assert tx.gas_price_coef == 0

      tx = Transaction.new() |> Transaction.put_gas_price_coef(255)
      assert tx.gas_price_coef == 255
    end
  end

  describe "put_depends_on/2" do
    test "sets depends_on with transaction ID" do
      tx_id = :crypto.strong_rand_bytes(32)
      tx = Transaction.new() |> Transaction.put_depends_on(tx_id)

      assert tx.depends_on == tx_id
    end

    test "sets depends_on to nil" do
      tx =
        Transaction.new()
        |> Transaction.put_depends_on(:crypto.strong_rand_bytes(32))
        |> Transaction.put_depends_on(nil)

      assert tx.depends_on == nil
    end

    test "validates depends_on is 32 bytes" do
      assert_raise ArgumentError, fn ->
        Transaction.new() |> Transaction.put_depends_on(<<1, 2, 3>>)
      end
    end
  end

  describe "put_nonce/2" do
    test "sets nonce" do
      tx = Transaction.new() |> Transaction.put_nonce(12345)

      assert tx.nonce == 12345
    end

    test "accepts large nonce values" do
      large_nonce = 0xFFFFFFFFFFFFFFFF
      tx = Transaction.new() |> Transaction.put_nonce(large_nonce)

      assert tx.nonce == large_nonce
    end
  end

  describe "put_signature/2" do
    test "sets signature" do
      signature = :crypto.strong_rand_bytes(65)
      tx = Transaction.new() |> Transaction.put_signature(signature)

      assert tx.signature == signature
    end

    test "accepts 65-byte signature (regular)" do
      signature = :crypto.strong_rand_bytes(65)
      tx = Transaction.new() |> Transaction.put_signature(signature)

      assert byte_size(tx.signature) == 65
    end

    test "accepts 130-byte signature (VIP-191)" do
      signature = :crypto.strong_rand_bytes(130)
      tx = Transaction.new() |> Transaction.put_signature(signature)

      assert byte_size(tx.signature) == 130
    end

    test "rejects invalid signature size" do
      assert_raise ArgumentError, fn ->
        Transaction.new() |> Transaction.put_signature(<<1, 2, 3>>)
      end
    end
  end

  describe "enable_vip191/1" do
    test "enables VIP-191 fee delegation" do
      tx = Transaction.new() |> Transaction.enable_vip191()

      assert Reserved.vip191_enabled?(tx.reserved)
    end

    test "is idempotent" do
      tx =
        Transaction.new()
        |> Transaction.enable_vip191()
        |> Transaction.enable_vip191()

      assert Reserved.vip191_enabled?(tx.reserved)
    end
  end

  describe "get_signing_hash/1" do
    test "returns 32-byte hash" do
      tx =
        Transaction.new(chain_tag: 0x27)
        |> Transaction.put_block_ref(<<0, 0, 0, 0, 0xAA, 0xBB, 0xCC, 0xDD>>)
        |> Transaction.add_clause(Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000))
        |> Transaction.put_gas(21000)

      {:ok, hash} = Transaction.get_signing_hash(tx)

      assert byte_size(hash) == 32
    end

    test "requires chain_tag" do
      tx = Transaction.new()

      assert {:error, _} = Transaction.get_signing_hash(tx)
    end

    test "requires block_ref" do
      tx = Transaction.new(chain_tag: 0x27)

      assert {:error, _} = Transaction.get_signing_hash(tx)
    end

    test "same transaction produces same hash" do
      tx =
        Transaction.new(chain_tag: 0x27)
        |> Transaction.put_block_ref(<<0, 0, 0, 0, 0xAA, 0xBB, 0xCC, 0xDD>>)
        |> Transaction.add_clause(Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000))
        |> Transaction.put_gas(21000)

      {:ok, hash1} = Transaction.get_signing_hash(tx)
      {:ok, hash2} = Transaction.get_signing_hash(tx)

      assert hash1 == hash2
    end

    test "different transactions produce different hashes" do
      base_tx =
        Transaction.new(chain_tag: 0x27)
        |> Transaction.put_block_ref(<<0, 0, 0, 0, 0xAA, 0xBB, 0xCC, 0xDD>>)
        |> Transaction.put_gas(21000)

      tx1 =
        base_tx
        |> Transaction.add_clause(Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000))

      tx2 =
        base_tx
        |> Transaction.add_clause(Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 2000))

      {:ok, hash1} = Transaction.get_signing_hash(tx1)
      {:ok, hash2} = Transaction.get_signing_hash(tx2)

      assert hash1 != hash2
    end
  end

  describe "get_transaction_id/1" do
    test "returns nil for unsigned transaction" do
      tx =
        Transaction.new(chain_tag: 0x27)
        |> Transaction.put_block_ref(<<0, 0, 0, 0, 0xAA, 0xBB, 0xCC, 0xDD>>)
        |> Transaction.add_clause(Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000))
        |> Transaction.put_gas(21000)

      assert Transaction.get_transaction_id(tx) == nil
    end
  end

  describe "encode/1" do
    test "encodes transaction to RLP bytes" do
      tx =
        Transaction.new(chain_tag: 0x27)
        |> Transaction.put_block_ref(<<0, 0, 0, 0, 0xAA, 0xBB, 0xCC, 0xDD>>)
        |> Transaction.put_expiration(32)
        |> Transaction.add_clause(Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000))
        |> Transaction.put_gas(21000)
        |> Transaction.put_nonce(12345)

      {:ok, encoded} = Transaction.encode(tx)

      assert is_binary(encoded)
      assert byte_size(encoded) > 0
    end

    test "requires minimum fields" do
      tx = Transaction.new()

      assert {:error, _} = Transaction.encode(tx)
    end
  end

  describe "decode/1" do
    test "decodes RLP bytes to transaction" do
      original_tx =
        Transaction.new(chain_tag: 0x27)
        |> Transaction.put_block_ref(<<0, 0, 0, 0, 0xAA, 0xBB, 0xCC, 0xDD>>)
        |> Transaction.put_expiration(32)
        |> Transaction.add_clause(Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000))
        |> Transaction.put_gas(21000)
        |> Transaction.put_nonce(12345)

      {:ok, encoded} = Transaction.encode(original_tx)
      {:ok, decoded_tx} = Transaction.decode(encoded)

      assert decoded_tx.chain_tag == original_tx.chain_tag
      assert decoded_tx.block_ref == original_tx.block_ref
      assert decoded_tx.expiration == original_tx.expiration
      assert length(decoded_tx.clauses) == length(original_tx.clauses)
      assert decoded_tx.gas == original_tx.gas
      assert decoded_tx.nonce == original_tx.nonce
    end

    test "returns error for invalid RLP" do
      assert {:error, _} = Transaction.decode(<<1, 2, 3>>)
    end
  end

  # Property-based tests - Disabled for now
  # @tag :skip
  # describe "property: encode/decode is reversible" do
  #   property "encoding and decoding preserves transaction fields" do
  #     check all(
  #             chain_tag <- integer(0..255),
  #             block_ref <- binary(length: 8),
  #             expiration <- integer(1..1000),
  #             gas <- integer(21_000..1_000_000),
  #             gas_price_coef <- integer(0..255),
  #             nonce <- integer(0..0xFFFFFFFF)
  #           ) do
  #       tx =
  #         Transaction.new(chain_tag: chain_tag)
  #         |> Transaction.put_block_ref(block_ref)
  #         |> Transaction.put_expiration(expiration)
  #         |> Transaction.add_clause(Clause.new(value: 1000))
  #         |> Transaction.put_gas(gas)
  #         |> Transaction.put_gas_price_coef(gas_price_coef)
  #         |> Transaction.put_nonce(nonce)

  #       {:ok, encoded} = Transaction.encode(tx)
  #       {:ok, decoded} = Transaction.decode(encoded)

  #       assert decoded.chain_tag == tx.chain_tag
  #       assert decoded.block_ref == tx.block_ref
  #       assert decoded.expiration == tx.expiration
  #       assert decoded.gas == tx.gas
  #       assert decoded.gas_price_coef == tx.gas_price_coef
  #       assert decoded.nonce == tx.nonce
  #     end
  #   end
  # end

  # describe "property: signing hash is deterministic" do
  #   property "same transaction produces same signing hash" do
  #     check all(
  #             chain_tag <- integer(0..255),
  #             block_ref <- binary(length: 8),
  #             value <- integer(1..1_000_000)
  #           ) do
  #       tx =
  #         Transaction.new(chain_tag: chain_tag)
  #         |> Transaction.put_block_ref(block_ref)
  #         |> Transaction.add_clause(Clause.new(value: value))
  #         |> Transaction.put_gas(21000)

  #       {:ok, hash1} = Transaction.get_signing_hash(tx)
  #       {:ok, hash2} = Transaction.get_signing_hash(tx)

  #       assert hash1 == hash2
  #       assert byte_size(hash1) == 32
  #     end
  #   end
  # end

  describe "multi-clause atomic transactions" do
    test "supports multiple clauses" do
      tx =
        Transaction.new(chain_tag: 0x27)
        |> Transaction.put_block_ref(<<0, 0, 0, 0, 0xAA, 0xBB, 0xCC, 0xDD>>)
        |> Transaction.add_clause(Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000))
        |> Transaction.add_clause(Clause.transfer_vet("0x1234567890123456789012345678901234567890", 2000))
        |> Transaction.add_clause(Clause.transfer_vtho("0xabcdef0123456789abcdef0123456789abcdef01", 3000))
        |> Transaction.put_gas(100000)

      assert length(tx.clauses) == 3

      {:ok, encoded} = Transaction.encode(tx)
      {:ok, decoded} = Transaction.decode(encoded)

      assert length(decoded.clauses) == 3
    end
  end

  describe "VIP-191 fee delegation" do
    test "reserved field indicates VIP-191 when enabled" do
      tx = Transaction.new() |> Transaction.enable_vip191()

      assert Reserved.vip191_enabled?(tx.reserved)
    end

    test "accepts 130-byte signature for delegated transactions" do
      signature = :crypto.strong_rand_bytes(130)

      tx =
        Transaction.new()
        |> Transaction.enable_vip191()
        |> Transaction.put_signature(signature)

      assert byte_size(tx.signature) == 130
    end
  end
end
