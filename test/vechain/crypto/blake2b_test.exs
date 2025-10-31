defmodule VeChain.Crypto.Blake2bTest do
  use ExUnit.Case, async: true
  doctest VeChain.Crypto.Blake2b

  alias VeChain.Crypto.Blake2b

  describe "hash/1" do
    test "produces 32-byte hash" do
      hash = Blake2b.hash("hello")
      assert byte_size(hash) == 32
    end

    test "produces consistent hashes" do
      hash1 = Blake2b.hash("test")
      hash2 = Blake2b.hash("test")
      assert hash1 == hash2
    end

    test "produces different hashes for different inputs" do
      hash1 = Blake2b.hash("test1")
      hash2 = Blake2b.hash("test2")
      assert hash1 != hash2
    end

    test "hashes empty string" do
      hash = Blake2b.hash("")
      assert byte_size(hash) == 32
      # Blake2b-256 of empty string
      assert hash ==
               <<14, 87, 81, 192, 38, 229, 67, 178, 232, 171, 46, 176, 96, 153, 218, 161, 209,
                 229, 223, 71, 119, 143, 119, 135, 250, 171, 69, 205, 241, 47, 227, 168>>
    end

    test "known test vector" do
      # "hello" hashed with Blake2b-256
      hash = Blake2b.hash("hello")

      assert hash ==
               <<50, 77, 207, 2, 125, 212, 163, 10, 147, 44, 68, 31, 54, 90, 37, 232,
                 107, 23, 61, 239, 164, 184, 229, 137, 72, 37, 52, 113, 184, 27, 114, 207>>
    end
  end

  describe "transaction_id/1" do
    test "produces 32-byte transaction ID" do
      tx_rlp = <<1, 2, 3, 4, 5>>
      tx_id = Blake2b.transaction_id(tx_rlp)
      assert byte_size(tx_id) == 32
    end

    test "is same as hash/1 for transaction RLP" do
      tx_rlp = <<1, 2, 3, 4, 5>>
      assert Blake2b.transaction_id(tx_rlp) == Blake2b.hash(tx_rlp)
    end
  end

  describe "public_key_to_address/1" do
    test "produces 20-byte address" do
      # Generate a dummy 64-byte public key
      public_key = <<1::512>>
      address = Blake2b.public_key_to_address(public_key)
      assert byte_size(address) == 20
    end

    test "uses last 20 bytes of hash" do
      public_key = <<2::512>>
      hash = Blake2b.hash(public_key)
      expected_address = binary_part(hash, 12, 20)

      address = Blake2b.public_key_to_address(public_key)
      assert address == expected_address
    end

    test "produces different addresses for different public keys" do
      pubkey1 = <<1::512>>
      pubkey2 = <<2::512>>

      addr1 = Blake2b.public_key_to_address(pubkey1)
      addr2 = Blake2b.public_key_to_address(pubkey2)

      assert addr1 != addr2
    end

    test "requires exactly 64 bytes" do
      assert_raise FunctionClauseError, fn ->
        Blake2b.public_key_to_address(<<1::520>>)
      end

      assert_raise FunctionClauseError, fn ->
        Blake2b.public_key_to_address(<<1::480>>)
      end
    end
  end

  describe "signing_hash/1" do
    test "produces 32-byte signing hash" do
      unsigned_tx = <<1, 2, 3, 4, 5>>
      hash = Blake2b.signing_hash(unsigned_tx)
      assert byte_size(hash) == 32
    end

    test "is same as hash/1" do
      unsigned_tx = <<1, 2, 3, 4, 5>>
      assert Blake2b.signing_hash(unsigned_tx) == Blake2b.hash(unsigned_tx)
    end
  end

  describe "hash_hex/1" do
    test "returns hex string with 0x prefix" do
      hex = Blake2b.hash_hex("hello")
      assert String.starts_with?(hex, "0x")
    end

    test "returns lowercase hex" do
      hex = Blake2b.hash_hex("hello")
      assert hex == String.downcase(hex)
    end

    test "returns 66 characters (0x + 64 hex digits)" do
      hex = Blake2b.hash_hex("hello")
      assert String.length(hex) == 66
    end

    test "known test vector" do
      hex = Blake2b.hash_hex("hello")
      assert hex == "0x324dcf027dd4a30a932c441f365a25e86b173defa4b8e58948253471b81b72cf"
    end
  end

  describe "verify_hash/2" do
    test "verifies correct hash (binary)" do
      data = "hello"
      hash = Blake2b.hash(data)
      assert Blake2b.verify_hash(data, hash)
    end

    test "verifies correct hash (hex string)" do
      data = "hello"
      hash = Blake2b.hash_hex(data)
      assert Blake2b.verify_hash(data, hash)
    end

    test "rejects incorrect hash" do
      data = "hello"
      wrong_hash = Blake2b.hash("world")
      refute Blake2b.verify_hash(data, wrong_hash)
    end

    test "rejects malformed hash" do
      assert_raise ArgumentError, fn ->
        Blake2b.verify_hash("hello", "invalid")
      end
    end
  end

  describe "hash_n/2" do
    test "single hash iteration" do
      data = "hello"
      assert Blake2b.hash_n(data, 1) == Blake2b.hash(data)
    end

    test "double hash" do
      data = "hello"
      expected = data |> Blake2b.hash() |> Blake2b.hash()
      assert Blake2b.hash_n(data, 2) == expected
    end

    test "triple hash" do
      data = "hello"
      expected = data |> Blake2b.hash() |> Blake2b.hash() |> Blake2b.hash()
      assert Blake2b.hash_n(data, 3) == expected
    end

    test "produces different results for different iterations" do
      data = "hello"
      hash1 = Blake2b.hash_n(data, 1)
      hash2 = Blake2b.hash_n(data, 2)
      hash3 = Blake2b.hash_n(data, 3)

      assert hash1 != hash2
      assert hash2 != hash3
      assert hash1 != hash3
    end

    test "all iterations produce 32-byte hashes" do
      data = "hello"

      for n <- 1..5 do
        hash = Blake2b.hash_n(data, n)
        assert byte_size(hash) == 32
      end
    end
  end

  describe "Blake2b vs Keccak-256 (critical difference)" do
    test "Blake2b produces different hash than Keccak-256" do
      data = "hello"

      # Blake2b hash
      blake2b_hash = Blake2b.hash(data)

      # Keccak-256 hash (for comparison)
      keccak_hash = ExKeccak.hash_256(data)

      # They should be DIFFERENT - this is the critical VeChain difference
      assert blake2b_hash != keccak_hash
      assert byte_size(blake2b_hash) == 32
      assert byte_size(keccak_hash) == 32
    end
  end
end
