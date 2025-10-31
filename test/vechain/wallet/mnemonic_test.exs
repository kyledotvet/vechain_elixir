defmodule VeChain.Wallet.MnemonicTest do
  use ExUnit.Case, async: true

  alias VeChain.Wallet.Mnemonic

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
end
