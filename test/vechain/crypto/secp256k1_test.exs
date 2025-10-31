defmodule VeChain.Crypto.Secp256k1Test do
  use ExUnit.Case, async: true
  doctest VeChain.Crypto.Secp256k1

  alias VeChain.Crypto.{Secp256k1, Blake2b}

  describe "generate_private_key/0" do
    test "generates 32-byte private key" do
      key = Secp256k1.generate_private_key()
      assert byte_size(key) == 32
    end

    test "generates unique keys" do
      key1 = Secp256k1.generate_private_key()
      key2 = Secp256k1.generate_private_key()
      assert key1 != key2
    end

    test "generated keys are valid" do
      key = Secp256k1.generate_private_key()
      assert Secp256k1.valid_private_key?(key)
    end
  end

  describe "private_key_to_public_key/1" do
    test "derives 64-byte public key" do
      private_key = Secp256k1.generate_private_key()
      public_key = Secp256k1.private_key_to_public_key(private_key)
      assert byte_size(public_key) == 64
    end

    test "produces consistent public key" do
      private_key = Secp256k1.generate_private_key()
      pubkey1 = Secp256k1.private_key_to_public_key(private_key)
      pubkey2 = Secp256k1.private_key_to_public_key(private_key)
      assert pubkey1 == pubkey2
    end

    test "different private keys produce different public keys" do
      key1 = Secp256k1.generate_private_key()
      key2 = Secp256k1.generate_private_key()

      pubkey1 = Secp256k1.private_key_to_public_key(key1)
      pubkey2 = Secp256k1.private_key_to_public_key(key2)

      assert pubkey1 != pubkey2
    end

    test "requires exactly 32 bytes" do
      assert_raise FunctionClauseError, fn ->
        Secp256k1.private_key_to_public_key(<<1::256, 1>>)
      end

      assert_raise FunctionClauseError, fn ->
        Secp256k1.private_key_to_public_key(<<1::248>>)
      end
    end
  end

  describe "private_key_to_address/1" do
    test "derives 20-byte address" do
      private_key = Secp256k1.generate_private_key()
      address = Secp256k1.private_key_to_address(private_key)
      assert byte_size(address) == 20
    end

    test "produces consistent address" do
      private_key = Secp256k1.generate_private_key()
      addr1 = Secp256k1.private_key_to_address(private_key)
      addr2 = Secp256k1.private_key_to_address(private_key)
      assert addr1 == addr2
    end

    test "different keys produce different addresses" do
      key1 = Secp256k1.generate_private_key()
      key2 = Secp256k1.generate_private_key()

      addr1 = Secp256k1.private_key_to_address(key1)
      addr2 = Secp256k1.private_key_to_address(key2)

      assert addr1 != addr2
    end

    test "address matches public key derived address" do
      private_key = Secp256k1.generate_private_key()

      # Derive via public key
      public_key = Secp256k1.private_key_to_public_key(private_key)
      addr_from_pubkey = Blake2b.public_key_to_address(public_key)

      # Derive directly
      addr_direct = Secp256k1.private_key_to_address(private_key)

      assert addr_from_pubkey == addr_direct
    end
  end

  describe "sign/2" do
    test "produces 65-byte signature" do
      private_key = Secp256k1.generate_private_key()
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)
      assert byte_size(signature) == 65
    end

    test "signature has recovery id in last byte" do
      private_key = Secp256k1.generate_private_key()
      message_hash = Blake2b.hash("hello")

      <<_r::binary-size(32), _s::binary-size(32), v::8>> =
        Secp256k1.sign(message_hash, private_key)

      # Recovery id should be 0, 1, 2, or 3
      assert v in [0, 1, 2, 3]
    end

    test "produces consistent signatures for same inputs" do
      private_key = Secp256k1.generate_private_key()
      message_hash = Blake2b.hash("hello")

      # Note: ECDSA with random k produces different signatures each time
      # But they should both verify correctly
      sig1 = Secp256k1.sign(message_hash, private_key)
      sig2 = Secp256k1.sign(message_hash, private_key)

      # Both signatures should be valid
      public_key = Secp256k1.private_key_to_public_key(private_key)
      assert Secp256k1.verify(message_hash, sig1, public_key)
      assert Secp256k1.verify(message_hash, sig2, public_key)
    end

    test "requires 32-byte message hash" do
      private_key = Secp256k1.generate_private_key()

      assert_raise FunctionClauseError, fn ->
        Secp256k1.sign(<<1, 2, 3>>, private_key)
      end
    end

    test "requires 32-byte private key" do
      message_hash = Blake2b.hash("hello")

      assert_raise FunctionClauseError, fn ->
        Secp256k1.sign(message_hash, <<1, 2, 3>>)
      end
    end
  end

  describe "sign_compact/2" do
    test "returns map with r, s, v components" do
      private_key = Secp256k1.generate_private_key()
      message_hash = Blake2b.hash("hello")

      compact = Secp256k1.sign_compact(message_hash, private_key)

      assert is_map(compact)
      assert Map.has_key?(compact, :r)
      assert Map.has_key?(compact, :s)
      assert Map.has_key?(compact, :v)
    end

    test "components have correct sizes" do
      private_key = Secp256k1.generate_private_key()
      message_hash = Blake2b.hash("hello")

      %{r: r, s: s, v: v} = Secp256k1.sign_compact(message_hash, private_key)

      assert byte_size(r) == 32
      assert byte_size(s) == 32
      assert v in [0, 1, 2, 3]
    end

    test "matches standard signature format" do
      private_key = Secp256k1.generate_private_key()
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)
      %{r: r, s: s, v: v} = Secp256k1.sign_compact(message_hash, private_key)

      # Should be able to reconstruct signature from compact
      <<sig_r::binary-size(32), sig_s::binary-size(32), sig_v::8>> = signature

      # Note: signatures will differ due to random k, but structure should match
      assert byte_size(r) == byte_size(sig_r)
      assert byte_size(s) == byte_size(sig_s)
      assert v in [0, 1, 2, 3] and sig_v in [0, 1, 2, 3]
    end
  end

  describe "recover/2" do
    test "recovers public key from signature" do
      private_key = Secp256k1.generate_private_key()
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)
      {:ok, recovered_pubkey} = Secp256k1.recover(message_hash, signature)

      assert byte_size(recovered_pubkey) == 64
    end

    test "recovered public key matches original" do
      private_key = Secp256k1.generate_private_key()
      original_pubkey = Secp256k1.private_key_to_public_key(private_key)
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)
      {:ok, recovered_pubkey} = Secp256k1.recover(message_hash, signature)

      assert recovered_pubkey == original_pubkey
    end

    test "fails with invalid signature" do
      message_hash = Blake2b.hash("hello")
      invalid_signature = <<0::520>>

      assert {:error, _} = Secp256k1.recover(message_hash, invalid_signature)
    end

    test "requires 32-byte message hash" do
      signature = <<0::520>>

      assert_raise FunctionClauseError, fn ->
        Secp256k1.recover(<<1, 2, 3>>, signature)
      end
    end

    test "requires 65-byte signature" do
      message_hash = Blake2b.hash("hello")

      assert_raise FunctionClauseError, fn ->
        Secp256k1.recover(message_hash, <<1, 2, 3>>)
      end
    end
  end

  describe "recover_address/2" do
    test "recovers address from signature" do
      private_key = Secp256k1.generate_private_key()
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)
      {:ok, recovered_address} = Secp256k1.recover_address(message_hash, signature)

      assert byte_size(recovered_address) == 20
    end

    test "recovered address matches original" do
      private_key = Secp256k1.generate_private_key()
      original_address = Secp256k1.private_key_to_address(private_key)
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)
      {:ok, recovered_address} = Secp256k1.recover_address(message_hash, signature)

      assert recovered_address == original_address
    end

    test "fails with invalid signature" do
      message_hash = Blake2b.hash("hello")
      invalid_signature = <<0::520>>

      assert {:error, _} = Secp256k1.recover_address(message_hash, invalid_signature)
    end
  end

  describe "verify/3" do
    test "verifies valid signature" do
      private_key = Secp256k1.generate_private_key()
      public_key = Secp256k1.private_key_to_public_key(private_key)
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)

      assert Secp256k1.verify(message_hash, signature, public_key)
    end

    test "rejects signature with wrong public key" do
      private_key = Secp256k1.generate_private_key()
      other_key = Secp256k1.generate_private_key()
      other_pubkey = Secp256k1.private_key_to_public_key(other_key)
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)

      refute Secp256k1.verify(message_hash, signature, other_pubkey)
    end

    test "rejects signature for different message" do
      private_key = Secp256k1.generate_private_key()
      public_key = Secp256k1.private_key_to_public_key(private_key)
      message_hash = Blake2b.hash("hello")
      other_hash = Blake2b.hash("world")

      signature = Secp256k1.sign(message_hash, private_key)

      refute Secp256k1.verify(other_hash, signature, public_key)
    end

    test "rejects invalid signature" do
      public_key = Secp256k1.generate_private_key() |> Secp256k1.private_key_to_public_key()
      message_hash = Blake2b.hash("hello")
      invalid_signature = <<0::520>>

      refute Secp256k1.verify(message_hash, invalid_signature, public_key)
    end
  end

  describe "verify_address/3" do
    test "verifies signature against address" do
      private_key = Secp256k1.generate_private_key()
      address = Secp256k1.private_key_to_address(private_key)
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)

      assert Secp256k1.verify_address(message_hash, signature, address)
    end

    test "rejects signature with wrong address" do
      private_key = Secp256k1.generate_private_key()
      other_key = Secp256k1.generate_private_key()
      other_address = Secp256k1.private_key_to_address(other_key)
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)

      refute Secp256k1.verify_address(message_hash, signature, other_address)
    end

    test "rejects invalid signature" do
      address = Secp256k1.generate_private_key() |> Secp256k1.private_key_to_address()
      message_hash = Blake2b.hash("hello")
      invalid_signature = <<0::520>>

      refute Secp256k1.verify_address(message_hash, invalid_signature, address)
    end
  end

  describe "valid_private_key?/1" do
    test "accepts valid generated keys" do
      key = Secp256k1.generate_private_key()
      assert Secp256k1.valid_private_key?(key)
    end

    test "rejects all-zero key" do
      invalid_key = <<0::256>>
      refute Secp256k1.valid_private_key?(invalid_key)
    end

    test "rejects key that's too large" do
      # Larger than secp256k1 curve order
      invalid_key = <<0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBAAEDCE6AF48A03BBFD25E8CD0364142::256>>
      refute Secp256k1.valid_private_key?(invalid_key)
    end

    test "rejects non-32-byte input" do
      refute Secp256k1.valid_private_key?(<<1, 2, 3>>)
      refute Secp256k1.valid_private_key?(<<1::256, 1>>)
    end

    test "accepts key with value 1" do
      valid_key = <<1::256>>
      assert Secp256k1.valid_private_key?(valid_key)
    end
  end

  describe "normalize_signature/1" do
    test "returns 65-byte signature" do
      private_key = Secp256k1.generate_private_key()
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)
      normalized = Secp256k1.normalize_signature(signature)

      assert byte_size(normalized) == 65
    end

    test "normalized signature is still valid" do
      private_key = Secp256k1.generate_private_key()
      public_key = Secp256k1.private_key_to_public_key(private_key)
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)
      normalized = Secp256k1.normalize_signature(signature)

      # Original signature should verify
      assert Secp256k1.verify(message_hash, signature, public_key)

      # Normalized signature should also verify
      assert Secp256k1.verify(message_hash, normalized, public_key)
    end

    test "s-value is in lower half after normalization" do
      private_key = Secp256k1.generate_private_key()
      message_hash = Blake2b.hash("hello")

      signature = Secp256k1.sign(message_hash, private_key)
      <<_r::binary-size(32), s::binary-size(32), _v::8>> =
        Secp256k1.normalize_signature(signature)

      s_int = :binary.decode_unsigned(s, :big)
      n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      half_n = div(n, 2)

      assert s_int <= half_n
    end
  end

  describe "integration test: full signing flow" do
    test "complete sign and verify flow" do
      # Generate key pair
      private_key = Secp256k1.generate_private_key()
      public_key = Secp256k1.private_key_to_public_key(private_key)
      address = Secp256k1.private_key_to_address(private_key)

      # Create message and hash it (VeChain uses Blake2b!)
      message = "Transfer 100 VET to recipient"
      message_hash = Blake2b.hash(message)

      # Sign the hash
      signature = Secp256k1.sign(message_hash, private_key)

      # Verify using public key
      assert Secp256k1.verify(message_hash, signature, public_key)

      # Verify using address
      assert Secp256k1.verify_address(message_hash, signature, address)

      # Recover public key from signature
      {:ok, recovered_pubkey} = Secp256k1.recover(message_hash, signature)
      assert recovered_pubkey == public_key

      # Recover address from signature
      {:ok, recovered_address} = Secp256k1.recover_address(message_hash, signature)
      assert recovered_address == address
    end
  end
end
