defmodule VeChain.Crypto.AddressTest do
  use ExUnit.Case, async: true

  alias VeChain.Crypto.{Address, Blake2b, Secp256k1}

  doctest VeChain.Crypto.Address

  @private_key Base.decode16!(
                 "7582BE841CA040AA940FFF6C05773129E135623690C06DBE3F7E014706FDDADF",
                 case: :mixed
               )

  describe "from_public_key/1" do
    test "derives address from uncompressed public key" do
      public_key = Secp256k1.private_key_to_public_key(@private_key)

      {:ok, address} = Address.from_public_key(public_key)

      assert byte_size(address) == 20
      assert is_binary(address)
    end

    test "handles 65-byte uncompressed public key with 0x04 prefix" do
      public_key = Secp256k1.private_key_to_public_key(@private_key)
      assert byte_size(public_key) == 65
      assert <<0x04, _rest::binary-size(64)>> = public_key

      {:ok, address} = Address.from_public_key(public_key)

      assert byte_size(address) == 20
    end

    test "rejects invalid public key size" do
      invalid_key = <<1, 2, 3, 4>>

      assert {:error, :invalid_public_key} = Address.from_public_key(invalid_key)
    end

    test "rejects compressed public key" do
      # Compressed keys start with 0x02 or 0x03 and are 33 bytes
      compressed_key = <<0x02>> <> :crypto.strong_rand_bytes(32)

      assert {:error, :invalid_public_key} = Address.from_public_key(compressed_key)
    end

    test "uses Blake2b for hashing" do
      public_key = Secp256k1.private_key_to_public_key(@private_key)
      <<0x04, public_key_without_prefix::binary-size(64)>> = public_key

      {:ok, address} = Address.from_public_key(public_key)

      # Manually calculate expected address
      hash = Blake2b.hash256(public_key_without_prefix)
      expected_address = binary_part(hash, 12, 20)

      assert address == expected_address
    end
  end

  describe "from_public_key!/1" do
    test "returns address for valid public key" do
      public_key = Secp256k1.private_key_to_public_key(@private_key)

      address = Address.from_public_key!(public_key)

      assert byte_size(address) == 20
    end

    test "raises for invalid public key" do
      assert_raise VeChain.Error.InvalidPublicKey, fn ->
        Address.from_public_key!(<<1, 2, 3, 4>>)
      end
    end
  end

  describe "from_private_key/1" do
    test "derives address from private key" do
      {:ok, address} = Address.from_private_key(@private_key)

      assert byte_size(address) == 20
    end

    test "derives same address as from_public_key" do
      {:ok, address1} = Address.from_private_key(@private_key)

      public_key = Secp256k1.private_key_to_public_key(@private_key)
      {:ok, address2} = Address.from_public_key(public_key)

      assert address1 == address2
    end

    test "rejects invalid private key size" do
      invalid_key = <<1, 2, 3>>

      assert {:error, _} = Address.from_private_key(invalid_key)
    end
  end

  describe "from_private_key!/1" do
    test "returns address for valid private key" do
      address = Address.from_private_key!(@private_key)

      assert byte_size(address) == 20
    end

    test "raises for invalid private key" do
      assert_raise VeChain.Error.InvalidPrivateKey, fn ->
        Address.from_private_key!(<<1, 2, 3>>)
      end
    end
  end

  describe "from_signature/2" do
    test "recovers address from signature and message hash" do
      message = "hello world"
      message_hash = Blake2b.hash256(message)

      {:ok, signature} = Secp256k1.sign(message_hash, @private_key)
      {:ok, recovered_address} = Address.from_signature(message_hash, signature)

      {:ok, expected_address} = Address.from_private_key(@private_key)

      assert recovered_address == expected_address
    end

    test "rejects invalid signature" do
      message_hash = Blake2b.hash256("test")
      invalid_signature = :crypto.strong_rand_bytes(65)

      result = Address.from_signature(message_hash, invalid_signature)

      assert {:error, _} = result
    end

    test "rejects wrong message hash" do
      message_hash = Blake2b.hash256("hello")
      {:ok, signature} = Secp256k1.sign(message_hash, @private_key)

      wrong_hash = Blake2b.hash256("goodbye")

      {:ok, recovered} = Address.from_signature(wrong_hash, signature)
      {:ok, expected} = Address.from_private_key(@private_key)

      # Should recover a different address
      assert recovered != expected
    end
  end

  describe "from_signature!/2" do
    test "returns address for valid signature" do
      message_hash = Blake2b.hash256("test")
      {:ok, signature} = Secp256k1.sign(message_hash, @private_key)

      address = Address.from_signature!(message_hash, signature)

      assert byte_size(address) == 20
    end

    test "raises for invalid signature" do
      message_hash = Blake2b.hash256("test")

      assert_raise VeChain.Error.SignatureError, fn ->
        Address.from_signature!(message_hash, <<1, 2, 3>>)
      end
    end
  end

  describe "validate/1" do
    test "validates correct address size" do
      {:ok, address} = Address.from_private_key(@private_key)

      assert Address.validate(address) == :ok
    end

    test "rejects invalid size" do
      assert {:error, :invalid_address_length} = Address.validate(<<1, 2, 3>>)
      assert {:error, :invalid_address_length} = Address.validate(:crypto.strong_rand_bytes(19))
      assert {:error, :invalid_address_length} = Address.validate(:crypto.strong_rand_bytes(21))
    end

    test "rejects non-binary input" do
      assert {:error, :invalid_address_format} = Address.validate("0x1234")
      assert {:error, :invalid_address_format} = Address.validate(123)
      assert {:error, :invalid_address_format} = Address.validate(nil)
    end
  end

  describe "validate!/1" do
    test "returns :ok for valid address" do
      {:ok, address} = Address.from_private_key(@private_key)

      assert Address.validate!(address) == :ok
    end

    test "raises for invalid address" do
      assert_raise VeChain.Error.InvalidAddress, fn ->
        Address.validate!(<<1, 2, 3>>)
      end
    end
  end

  describe "VeChain vs Ethereum address derivation" do
    test "uses Blake2b instead of Keccak256" do
      # This test documents that VeChain uses Blake2b, not Keccak
      public_key = Secp256k1.private_key_to_public_key(@private_key)
      <<0x04, public_key_without_prefix::binary-size(64)>> = public_key

      # VeChain way (Blake2b)
      {:ok, vechain_address} = Address.from_public_key(public_key)

      # What Ethereum would do (Keccak256)
      ethereum_hash = ExKeccak.hash_256(public_key_without_prefix)
      ethereum_address = binary_part(ethereum_hash, 12, 20)

      # Should be different
      assert vechain_address != ethereum_address
    end
  end

  describe "address consistency" do
    test "same private key always produces same address" do
      {:ok, address1} = Address.from_private_key(@private_key)
      {:ok, address2} = Address.from_private_key(@private_key)
      {:ok, address3} = Address.from_private_key(@private_key)

      assert address1 == address2
      assert address2 == address3
    end

    test "different private keys produce different addresses" do
      key1 = Secp256k1.generate_private_key()
      key2 = Secp256k1.generate_private_key()

      {:ok, address1} = Address.from_private_key(key1)
      {:ok, address2} = Address.from_private_key(key2)

      assert address1 != address2
    end
  end
end
