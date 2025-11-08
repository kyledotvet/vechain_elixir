defmodule VeChain.Wallet.MnemonicTest do
  @moduledoc """
  Tests for Mnemonic functionality including BIP39 mnemonic generation, validation, and key derivation.
  """
  use ExUnit.Case, async: true

  alias VeChain.Wallet.{Mnemonic, HD}
  alias VeChain.Crypto.{Address, Secp256k1}

  # Test fixture mnemonic phrase
  @test_words [
    "ignore",
    "empty",
    "bird",
    "silly",
    "journey",
    "junior",
    "ripple",
    "have",
    "guard",
    "waste",
    "between",
    "tenant"
  ]

  describe "generate/1" do
    test "generates 12-word mnemonic by default" do
      {:ok, mnemonic} = Mnemonic.generate()
      assert is_list(mnemonic)
      assert length(mnemonic) == 12
    end

    test "generates 12-word mnemonic" do
      {:ok, mnemonic} = Mnemonic.generate(12)
      assert length(mnemonic) == 12
    end

    test "generates 15-word mnemonic" do
      {:ok, mnemonic} = Mnemonic.generate(15)
      assert length(mnemonic) == 15
    end

    test "generates 18-word mnemonic" do
      {:ok, mnemonic} = Mnemonic.generate(18)
      assert length(mnemonic) == 18
    end

    test "generates 21-word mnemonic" do
      {:ok, mnemonic} = Mnemonic.generate(21)
      assert length(mnemonic) == 21
    end

    test "generates 24-word mnemonic" do
      {:ok, mnemonic} = Mnemonic.generate(24)
      assert length(mnemonic) == 24
    end

    test "returns error for invalid word count" do
      assert {:error, :invalid_word_count} = Mnemonic.generate(10)
      assert {:error, :invalid_word_count} = Mnemonic.generate(13)
      assert {:error, :invalid_word_count} = Mnemonic.generate(25)
    end

    test "generates different mnemonics each time" do
      {:ok, mnemonic1} = Mnemonic.generate()
      {:ok, mnemonic2} = Mnemonic.generate()
      assert mnemonic1 != mnemonic2
    end
  end

  describe "generate!/1" do
    test "generates mnemonic successfully" do
      mnemonic = Mnemonic.generate!()
      assert is_list(mnemonic)
      assert length(mnemonic) == 12
    end

    test "raises on invalid word count" do
      assert_raise ArgumentError, fn ->
        Mnemonic.generate!(10)
      end
    end
  end

  describe "encode/1 and decode/1" do
    test "encodes and decodes 16-byte entropy" do
      entropy = :crypto.strong_rand_bytes(16)
      {:ok, mnemonic} = Mnemonic.encode(entropy)
      assert length(mnemonic) == 12

      {:ok, decoded_entropy} = Mnemonic.decode(mnemonic)
      assert decoded_entropy == entropy
    end

    test "encodes and decodes 20-byte entropy" do
      entropy = :crypto.strong_rand_bytes(20)
      {:ok, mnemonic} = Mnemonic.encode(entropy)
      assert length(mnemonic) == 15

      {:ok, decoded_entropy} = Mnemonic.decode(mnemonic)
      assert decoded_entropy == entropy
    end

    test "encodes and decodes 24-byte entropy" do
      entropy = :crypto.strong_rand_bytes(24)
      {:ok, mnemonic} = Mnemonic.encode(entropy)
      assert length(mnemonic) == 18

      {:ok, decoded_entropy} = Mnemonic.decode(mnemonic)
      assert decoded_entropy == entropy
    end

    test "encodes and decodes 28-byte entropy" do
      entropy = :crypto.strong_rand_bytes(28)
      {:ok, mnemonic} = Mnemonic.encode(entropy)
      assert length(mnemonic) == 21

      {:ok, decoded_entropy} = Mnemonic.decode(mnemonic)
      assert decoded_entropy == entropy
    end

    test "encodes and decodes 32-byte entropy" do
      entropy = :crypto.strong_rand_bytes(32)
      {:ok, mnemonic} = Mnemonic.encode(entropy)
      assert length(mnemonic) == 24

      {:ok, decoded_entropy} = Mnemonic.decode(mnemonic)
      assert decoded_entropy == entropy
    end

    test "returns error for invalid entropy length" do
      assert {:error, :invalid_entropy_length} = Mnemonic.encode(<<1, 2, 3>>)
      assert {:error, :invalid_entropy_length} = Mnemonic.encode(:crypto.strong_rand_bytes(15))
      assert {:error, :invalid_entropy_length} = Mnemonic.encode(:crypto.strong_rand_bytes(33))
    end

    test "returns error for invalid checksum" do
      {:ok, mnemonic} = Mnemonic.generate()
      # Corrupt the last word
      bad_mnemonic = List.replace_at(mnemonic, -1, "abandon")
      assert {:error, :invalid_checksum} = Mnemonic.decode(bad_mnemonic)
    end

    test "returns error for invalid word" do
      assert {:error, :invalid_word} = Mnemonic.decode(["notaword", "invalid", "test"])
    end
  end

  describe "encode!/1 and decode!/1" do
    test "raise on errors" do
      assert_raise ArgumentError, fn ->
        Mnemonic.encode!(<<1, 2, 3>>)
      end

      assert_raise ArgumentError, fn ->
        Mnemonic.decode!(["notaword"])
      end
    end
  end

  describe "valid?/1" do
    test "returns true for valid mnemonic" do
      {:ok, mnemonic} = Mnemonic.generate()
      assert Mnemonic.valid?(mnemonic)
    end

    test "returns false for invalid checksum" do
      {:ok, mnemonic} = Mnemonic.generate()
      bad_mnemonic = List.replace_at(mnemonic, -1, "abandon")
      refute Mnemonic.valid?(bad_mnemonic)
    end

    test "returns false for invalid word" do
      refute Mnemonic.valid?(["notaword", "invalid"])
    end
  end

  describe "to_seed/2" do
    test "generates 64-byte seed from mnemonic" do
      {:ok, mnemonic} = Mnemonic.generate()
      {:ok, seed} = Mnemonic.to_seed(mnemonic)
      assert byte_size(seed) == 64
    end

    test "generates same seed for same mnemonic" do
      {:ok, mnemonic} = Mnemonic.generate()
      {:ok, seed1} = Mnemonic.to_seed(mnemonic)
      {:ok, seed2} = Mnemonic.to_seed(mnemonic)
      assert seed1 == seed2
    end

    test "generates different seeds with different passphrases" do
      {:ok, mnemonic} = Mnemonic.generate()
      {:ok, seed1} = Mnemonic.to_seed(mnemonic, "")
      {:ok, seed2} = Mnemonic.to_seed(mnemonic, "passphrase")
      assert seed1 != seed2
    end

    test "works with BIP39 test vectors" do
      # Test vector from BIP39 spec
      # Entropy: 00000000000000000000000000000000
      entropy = <<0::128>>
      {:ok, mnemonic} = Mnemonic.encode(entropy)

      # Should generate specific mnemonic
      expected_mnemonic = [
        "abandon",
        "abandon",
        "abandon",
        "abandon",
        "abandon",
        "abandon",
        "abandon",
        "abandon",
        "abandon",
        "abandon",
        "abandon",
        "about"
      ]

      assert mnemonic == expected_mnemonic

      # Seed with "TREZOR" passphrase
      {:ok, seed} = Mnemonic.to_seed(mnemonic, "TREZOR")

      # Expected seed (first 32 bytes shown)
      expected_seed_prefix =
        "c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04"

      assert Base.encode16(seed, case: :lower) == expected_seed_prefix
    end
  end

  describe "to_seed!/2" do
    test "returns seed without tuple" do
      {:ok, mnemonic} = Mnemonic.generate()
      seed = Mnemonic.to_seed!(mnemonic)
      assert is_binary(seed)
      assert byte_size(seed) == 64
    end
  end

  describe "to_private_key/3" do
    test "derives private key from default BIP44 VET derivation path" do
      # Expected private key for test mnemonic at default path
      expected =
        "27196338e7d0b5e7bf1be1c0327c53a244a18ef0b102976980e341500f492425"
        |> Base.decode16!(case: :lower)

      {:ok, actual} = Mnemonic.to_private_key(@test_words)

      assert actual == expected
    end

    test "derives consistent private keys using index vs full path" do
      # Verify child derivation consistency across derivation methods
      {:ok, master} = HD.from_mnemonic(@test_words, HD.vet_derivation_path())

      for i <- 0..9 do
        # Derive using index
        {:ok, child_from_index} = HD.derive_child(master, i)

        # Derive using full path
        path = "#{HD.vet_derivation_path()}/#{i}"
        {:ok, child_from_path} = HD.from_mnemonic(@test_words, path)

        # Both methods should give same result
        assert child_from_index.private_key == child_from_path.private_key

        # Direct private key derivation should also match
        {:ok, private_key} = Mnemonic.to_private_key(@test_words, path)
        assert child_from_path.private_key == private_key
      end
    end

    test "derives from custom m/0/1 derivation path" do
      # Expected private key for test mnemonic at custom path
      path = "m/0/1"

      expected =
        "731311cb9643cf4cf7a3a051fe02ae56cf6887708d1f2d3b07e1b4bebeb742a8"
        |> Base.decode16!(case: :lower)

      {:ok, actual} = Mnemonic.to_private_key(@test_words, path)

      assert actual == expected
    end

    test "derives from deep custom m/0/1/4/2/4/3 derivation path" do
      # Expected private key for test mnemonic at deep custom path
      path = "m/0/1/4/2/4/3"

      expected =
        "4d61a740e8e9964284c96e92e5e95e05eb732d61a5c3fb1557ca99398f041ba0"
        |> Base.decode16!(case: :lower)

      {:ok, actual} = Mnemonic.to_private_key(@test_words, path)

      assert actual == expected
    end

    test "returns error for invalid derivation path with non-numeric segment" do
      illegal_path = "m/0/1/4/2/4/h"
      assert {:error, :invalid_path} = Mnemonic.to_private_key(@test_words, illegal_path)
    end

    test "generates valid private keys and addresses for all mnemonic lengths" do
      # Verify all supported mnemonic lengths produce valid keys and addresses
      [12, 15, 18, 21, 24]
      |> Enum.each(fn length ->
        # Generate mnemonic words of expected length
        {:ok, words} = Mnemonic.generate(length)
        assert length(words) == length

        # Validate mnemonic words
        assert Mnemonic.valid?(words) == true

        # Derive private key from mnemonic words
        {:ok, private_key} = Mnemonic.to_private_key(words)
        assert byte_size(private_key) == 32
        assert Secp256k1.valid_private_key?(private_key)

        # Derive address from mnemonic words
        address_bytes = Address.from_private_key(private_key)
        address = "0x" <> Base.encode16(address_bytes, case: :lower)
        assert String.length(address) == 42
        assert Address.valid?(address)
      end)
    end

    test "returns error for invalid mnemonic" do
      assert Mnemonic.valid?(["hello", "world"]) == false
      assert {:error, :invalid_mnemonic} = Mnemonic.to_private_key(["hello", "world"])
    end

    test "returns error for invalid path" do
      assert {:error, :invalid_path} = Mnemonic.to_private_key(@test_words, "invalid")
      assert {:error, :invalid_path} = Mnemonic.to_private_key(@test_words, "m/-1")
      assert {:error, :invalid_path} = Mnemonic.to_private_key(@test_words, "m/a/b")
    end

    test "returns error for corrupted checksum" do
      {:ok, words} = Mnemonic.generate()
      # Corrupt last word
      bad_words = List.replace_at(words, -1, "abandon")
      assert Mnemonic.valid?(bad_words) == false
      assert {:error, _} = Mnemonic.to_private_key(bad_words)
    end
  end

  describe "Address derivation from mnemonic" do
    test "derives valid addresses from mnemonic at different indices" do
      addresses =
        for i <- 0..9 do
          path = "#{HD.vet_derivation_path()}/#{i}"
          {:ok, private_key} = Mnemonic.to_private_key(@test_words, path)
          address_bytes = Address.from_private_key(private_key)
          "0x" <> Base.encode16(address_bytes, case: :lower)
        end

      # All addresses should be unique
      assert length(Enum.uniq(addresses)) == 10

      # All addresses should be valid
      Enum.each(addresses, fn addr ->
        assert String.starts_with?(addr, "0x")
        assert String.length(addr) == 42
        assert Address.valid?(addr)
      end)
    end

    test "same mnemonic always generates same addresses" do
      path = "#{HD.vet_derivation_path()}/0"

      {:ok, private_key1} = Mnemonic.to_private_key(@test_words, path)
      address_bytes1 = Address.from_private_key(private_key1)
      address1 = "0x" <> Base.encode16(address_bytes1, case: :lower)

      {:ok, private_key2} = Mnemonic.to_private_key(@test_words, path)
      address_bytes2 = Address.from_private_key(private_key2)
      address2 = "0x" <> Base.encode16(address_bytes2, case: :lower)

      assert address1 == address2
    end
  end

  describe "Complete workflows" do
    test "derives address from generated mnemonic through full key derivation" do
      # Generate new mnemonic
      {:ok, words} = Mnemonic.generate()
      assert length(words) == 12
      assert Mnemonic.valid?(words)

      # Convert to seed
      {:ok, seed} = Mnemonic.to_seed(words)
      assert byte_size(seed) == 64

      # Create master key
      {:ok, master_key} = HD.master_key_from_seed(seed)
      assert byte_size(master_key.private_key) == 32

      # Derive first address
      {:ok, address_key} = HD.derive_address(master_key, 0, 0)
      address_bytes = Address.from_private_key(HD.private_key(address_key))
      address = "0x" <> Base.encode16(address_bytes, case: :lower)

      # Verify address
      assert String.starts_with?(address, "0x")
      assert String.length(address) == 42
      assert Address.valid?(address)

      # Same workflow should give same result
      {:ok, seed2} = Mnemonic.to_seed(words)
      {:ok, master_key2} = HD.master_key_from_seed(seed2)
      {:ok, address_key2} = HD.derive_address(master_key2, 0, 0)
      address_bytes2 = Address.from_private_key(HD.private_key(address_key2))
      address2 = "0x" <> Base.encode16(address_bytes2, case: :lower)

      assert address == address2
    end

    test "direct private key derivation matches HD key derivation" do
      {:ok, words} = Mnemonic.generate()

      # Method 1: Direct private key derivation
      path = "#{HD.vet_derivation_path()}/0"
      {:ok, private_key_direct} = Mnemonic.to_private_key(words, path)

      # Method 2: HD key derivation
      {:ok, hd_key} = HD.from_mnemonic(words, path)
      private_key_hd = HD.private_key(hd_key)

      # Both methods should give same result
      assert private_key_direct == private_key_hd

      # Addresses should also match
      address_bytes_direct = Address.from_private_key(private_key_direct)
      address_bytes_hd = Address.from_private_key(HD.private_key(hd_key))
      assert address_bytes_direct == address_bytes_hd
    end
  end
end
