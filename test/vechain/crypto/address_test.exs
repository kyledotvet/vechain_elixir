defmodule VeChain.Crypto.AddressTest do
  @moduledoc """
  Tests for VeChain address derivation and validation.
  """
  use ExUnit.Case, async: true

  alias VeChain.Crypto.{Address, Secp256k1}

  doctest VeChain.Crypto.Address

  @test_private_key Base.decode16!(
                      "5434C159B817C377A55F6BE66369622976014E78BCE2ADFD3E44E5DE88CE502F",
                      case: :mixed
                    )

  @test_public_key Base.decode16!(
                     "04A6711E14234B1D4E69AEED2ACF18B9C3BD0E97DB317B509516BD3A87E5B732685CCAF855D9F8A955BC1F420B4EBF8F682C2E480D98A360E7FD0C08E6EEF65607",
                     case: :mixed
                   )

  @expected_address "0x769E8AA372c8309c834EA6749B88861FF73581FF"

  describe "from_public_key/1" do
    test "derives address from 64-byte public key using Keccak-256" do
      <<0x04, public_key_64::binary-size(64)>> = @test_public_key

      address = Address.from_public_key(public_key_64)

      assert byte_size(address) == 20
      assert is_binary(address)

      # Verify it matches the expected address from the TypeScript SDK
      address_hex =
        VeChain.Utils.to_checksum_address("0x" <> Base.encode16(address, case: :lower))

      assert address_hex == @expected_address
    end

    test "uses Keccak-256, not Blake2b" do
      <<0x04, public_key_64::binary-size(64)>> = @test_public_key

      # Our implementation (should use Keccak-256)
      our_address = Address.from_public_key(public_key_64)

      # Keccak-256 (correct)
      keccak_hash = ExKeccak.hash_256(public_key_64)
      keccak_address = binary_part(keccak_hash, 12, 20)

      # Blake2b (incorrect)
      blake2b_hash = Blake2.hash2b(public_key_64, 32)
      blake2b_address = binary_part(blake2b_hash, 12, 20)

      # Should match Keccak-256
      assert our_address == keccak_address

      # Should NOT match Blake2b
      refute our_address == blake2b_address
    end
  end

  describe "from_private_key/1" do
    test "derives correct address from private key" do
      address = Address.from_private_key(@test_private_key)

      assert byte_size(address) == 20

      # Verify it matches the expected address from the TypeScript SDK
      address_hex =
        VeChain.Utils.to_checksum_address("0x" <> Base.encode16(address, case: :lower))

      assert address_hex == @expected_address
    end

    test "derives same address as from_public_key" do
      address1 = Address.from_private_key(@test_private_key)

      <<0x04, public_key_64::binary-size(64)>> = @test_public_key
      address2 = Address.from_public_key(public_key_64)

      assert address1 == address2
    end
  end

  describe "from_signature/2" do
    test "recovers address from signature and message hash" do
      message_hash = Blake2.hash2b("hello world", 32)
      signature = Secp256k1.sign(message_hash, @test_private_key)

      {:ok, recovered_address} = Address.from_signature(message_hash, signature)

      expected_address = Address.from_private_key(@test_private_key)

      assert recovered_address == expected_address
    end

    test "rejects invalid signature" do
      message_hash = Blake2.hash2b("test", 32)
      invalid_signature = :crypto.strong_rand_bytes(65)

      result = Address.from_signature(message_hash, invalid_signature)

      assert {:error, _} = result
    end

    test "recovers different address for wrong message hash" do
      message_hash = Blake2.hash2b("hello", 32)
      signature = Secp256k1.sign(message_hash, @test_private_key)

      wrong_hash = Blake2.hash2b("goodbye", 32)

      {:ok, recovered} = Address.from_signature(wrong_hash, signature)
      expected = Address.from_private_key(@test_private_key)

      # Should recover a different address
      assert recovered != expected
    end
  end

  describe "address derivation from private key" do
    test "derives correct address from known private key" do
      address = Address.from_private_key(@test_private_key)

      address_hex =
        VeChain.Utils.to_checksum_address("0x" <> Base.encode16(address, case: :lower))

      assert address_hex == @expected_address,
             """
             Address derivation mismatch!

             Expected: #{@expected_address}
             Got:      #{address_hex}
             """
    end

    test "derives correct address from known public key" do
      <<0x04, public_key_64::binary-size(64)>> = @test_public_key

      address = Address.from_public_key(public_key_64)

      address_hex =
        VeChain.Utils.to_checksum_address("0x" <> Base.encode16(address, case: :lower))

      assert address_hex == @expected_address,
             """
             Address derivation mismatch!

             Expected: #{@expected_address}
             Got:      #{address_hex}
             """
    end

    test "derives correct public key from private key" do
      public_key = Secp256k1.private_key_to_public_key(@test_private_key)
      expected_without_prefix = binary_part(@test_public_key, 1, 64)

      assert public_key == expected_without_prefix,
             """
             Public key derivation mismatch!

             Expected: #{Base.encode16(expected_without_prefix, case: :lower)}
             Got:      #{Base.encode16(public_key, case: :lower)}
             """
    end
  end

  describe "VeChain vs Ethereum address derivation" do
    test "VeChain uses SAME algorithm as Ethereum (Keccak-256)" do
      <<0x04, public_key_64::binary-size(64)>> = @test_public_key

      # VeChain way
      vechain_address = Address.from_public_key(public_key_64)

      # Ethereum way (uses Keccak-256)
      ethereum_hash = ExKeccak.hash_256(public_key_64)
      ethereum_address = binary_part(ethereum_hash, 12, 20)

      # Should be the SAME because VeChain uses Keccak-256 for addresses
      assert vechain_address == ethereum_address,
             """
             VeChain and Ethereum should produce the same address!

             VeChain uses Keccak-256 for address derivation (same as Ethereum).
             Only transaction IDs and signing hashes use Blake2b.
             """
    end
  end

  describe "Secp256k1 module consistency" do
    test "Secp256k1.private_key_to_address matches Address.from_private_key" do
      address1 = Secp256k1.private_key_to_address(@test_private_key)
      address2 = Address.from_private_key(@test_private_key)

      assert address1 == address2

      # Both should match the expected address
      address_hex =
        VeChain.Utils.to_checksum_address("0x" <> Base.encode16(address1, case: :lower))

      assert address_hex == @expected_address
    end

    test "Secp256k1.recover_address matches Address.from_signature" do
      message_hash = Blake2.hash2b("test message", 32)
      signature = Secp256k1.sign(message_hash, @test_private_key)

      {:ok, recovered1} = Secp256k1.recover_address(message_hash, signature)
      {:ok, recovered2} = Address.from_signature(message_hash, signature)

      assert recovered1 == recovered2

      # Should match the expected address
      expected = Address.from_private_key(@test_private_key)
      assert recovered1 == expected
    end
  end

  describe "address consistency" do
    test "same private key always produces same address" do
      address1 = Address.from_private_key(@test_private_key)
      address2 = Address.from_private_key(@test_private_key)
      address3 = Address.from_private_key(@test_private_key)

      assert address1 == address2
      assert address2 == address3
    end

    test "different private keys produce different addresses" do
      key1 = Secp256k1.generate_private_key()
      key2 = Secp256k1.generate_private_key()

      address1 = Address.from_private_key(key1)
      address2 = Address.from_private_key(key2)

      assert address1 != address2
    end
  end
end
