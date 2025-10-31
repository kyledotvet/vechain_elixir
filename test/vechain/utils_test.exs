defmodule VeChain.UtilsTest do
  use ExUnit.Case, async: true
  doctest VeChain.Utils

  alias VeChain.Utils

  describe "to_binary/1" do
    test "passes through 20-byte binary" do
      binary = <<1::160>>
      assert {:ok, ^binary} = Utils.to_binary(binary)
    end

    test "decodes hex with 0x prefix" do
      hex = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      {:ok, binary} = Utils.to_binary(hex)
      assert byte_size(binary) == 20
    end

    test "decodes hex without prefix" do
      hex = "7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      {:ok, binary} = Utils.to_binary(hex)
      assert byte_size(binary) == 20
    end

    test "handles mixed case hex" do
      hex = "0x7567D83b7B8d80ADdcb281a71D54Fc7B3364ffeD"
      {:ok, binary} = Utils.to_binary(hex)
      assert byte_size(binary) == 20
    end

    test "rejects invalid hex" do
      assert {:error, _} = Utils.to_binary("0xZZZ")
    end

    test "rejects wrong length" do
      assert {:error, _} = Utils.to_binary("0x1234")
      assert {:error, _} = Utils.to_binary(<<1, 2, 3>>)
    end

    test "to_binary and to_hex roundtrip" do
      original = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      {:ok, binary} = Utils.to_binary(original)
      {:ok, hex} = Utils.to_hex(binary)
      assert hex == original
    end
  end

  describe "to_hex/1" do
    test "converts binary to hex with 0x prefix" do
      binary = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
      {:ok, hex} = Utils.to_hex(binary)
      assert hex == "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
    end

    test "handles hex string input" do
      input = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      {:ok, hex} = Utils.to_hex(input)
      assert hex == input
    end

    test "normalizes to lowercase" do
      binary = <<255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255>>
      {:ok, hex} = Utils.to_hex(binary)
      assert hex == "0xffffffffffffffffffffffffffffffffffffffff"
    end

    test "rejects invalid input" do
      assert {:error, _} = Utils.to_hex(<<1, 2, 3>>)
    end
  end

  describe "checksum_address/1" do
    test "generates checksummed address" do
      address = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      {:ok, checksummed} = Utils.checksum_address(address)

      # Should have mixed case
      assert checksummed != String.downcase(checksummed)
      assert checksummed != String.upcase(checksummed)
      assert String.starts_with?(checksummed, "0x")
    end

    test "checksum is consistent" do
      address = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      {:ok, checksum1} = Utils.checksum_address(address)
      {:ok, checksum2} = Utils.checksum_address(address)
      assert checksum1 == checksum2
    end

    test "handles binary input" do
      binary = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
      {:ok, checksummed} = Utils.checksum_address(binary)
      assert String.starts_with?(checksummed, "0x")
    end

    test "checksum is case-sensitive" do
      address = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      {:ok, checksummed} = Utils.checksum_address(address)

      # Some characters should be uppercase, some lowercase
      assert Regex.match?(~r/[a-z]/, checksummed)
      assert Regex.match?(~r/[A-F]/, checksummed)
    end
  end

  describe "valid_checksum?/1" do
    test "validates correctly checksummed address" do
      address = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      {:ok, checksummed} = Utils.checksum_address(address)
      assert Utils.valid_checksum?(checksummed)
    end

    test "rejects all lowercase" do
      address = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      refute Utils.valid_checksum?(address)
    end

    test "rejects all uppercase" do
      address = "0X7567D83B7B8D80ADDCB281A71D54FC7B3364FFED"
      refute Utils.valid_checksum?(address)
    end

    test "rejects incorrect checksum" do
      # Deliberately wrong checksum
      address = "0x7567D83B7b8d80addcb281a71d54fc7b3364ffed"
      refute Utils.valid_checksum?(address)
    end

    test "rejects invalid format" do
      refute Utils.valid_checksum?("invalid")
      refute Utils.valid_checksum?("0x123")
    end
  end

  describe "valid_address?/1" do
    test "accepts valid 20-byte binary" do
      address = <<1::160>>
      assert Utils.valid_address?(address)
    end

    test "accepts valid hex with 0x prefix" do
      address = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      assert Utils.valid_address?(address)
    end

    test "accepts valid hex without prefix" do
      address = "7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      assert Utils.valid_address?(address)
    end

    test "rejects invalid length" do
      refute Utils.valid_address?(<<1, 2, 3>>)
      refute Utils.valid_address?("0x1234")
    end

    test "rejects invalid hex" do
      refute Utils.valid_address?("0xZZZ")
    end
  end

  describe "encode_hex/1" do
    test "encodes binary to hex with 0x prefix" do
      binary = <<1, 2, 3>>
      assert Utils.encode_hex(binary) == "0x010203"
    end

    test "uses lowercase hex" do
      binary = <<255, 254, 253>>
      assert Utils.encode_hex(binary) == "0xfffefd"
    end

    test "handles empty binary" do
      assert Utils.encode_hex(<<>>) == "0x"
    end

    test "handles string input" do
      assert Utils.encode_hex("hello") == "0x68656c6c6f"
    end
  end

  describe "decode_hex/1" do
    test "decodes hex with 0x prefix" do
      {:ok, binary} = Utils.decode_hex("0x010203")
      assert binary == <<1, 2, 3>>
    end

    test "decodes hex without prefix" do
      {:ok, binary} = Utils.decode_hex("010203")
      assert binary == <<1, 2, 3>>
    end

    test "handles mixed case" do
      {:ok, binary} = Utils.decode_hex("0xAbCdEf")
      assert binary == <<0xAB, 0xCD, 0xEF>>
    end

    test "handles empty string" do
      {:ok, binary} = Utils.decode_hex("0x")
      assert binary == <<>>
    end

    test "rejects invalid hex" do
      assert {:error, _} = Utils.decode_hex("0xZZZ")
      assert {:error, _} = Utils.decode_hex("XYZ")
    end

    test "encode and decode roundtrip" do
      original = <<1, 2, 3, 4, 5>>
      hex = Utils.encode_hex(original)
      {:ok, decoded} = Utils.decode_hex(hex)
      assert decoded == original
    end
  end

  describe "vet_to_wei/1" do
    test "converts 1 VET to wei" do
      assert Utils.vet_to_wei(1) == 1_000_000_000_000_000_000
    end

    test "converts fractional VET" do
      assert Utils.vet_to_wei(0.5) == 500_000_000_000_000_000
    end

    test "converts large amounts" do
      assert Utils.vet_to_wei(1000) == 1_000_000_000_000_000_000_000
    end

    test "handles zero" do
      assert Utils.vet_to_wei(0) == 0
    end

    test "truncates to integer" do
      # Should truncate fractional wei
      result = Utils.vet_to_wei(0.123456789123456789123)
      assert is_integer(result)
    end
  end

  describe "wei_to_vet/1" do
    test "converts wei to VET" do
      assert Utils.wei_to_vet(1_000_000_000_000_000_000) == 1.0
    end

    test "converts fractional VET amounts" do
      assert Utils.wei_to_vet(500_000_000_000_000_000) == 0.5
    end

    test "handles zero" do
      assert Utils.wei_to_vet(0) == 0.0
    end

    test "vet_to_wei and wei_to_vet roundtrip" do
      vet = 123.456
      wei = Utils.vet_to_wei(vet)
      back_to_vet = Utils.wei_to_vet(wei)
      # Allow small floating point error
      assert_in_delta back_to_vet, vet, 0.000001
    end
  end

  describe "vtho_to_wei/1" do
    test "converts VTHO to wei" do
      assert Utils.vtho_to_wei(100) == 100_000_000_000_000_000_000
    end

    test "same as vet_to_wei" do
      amount = 42.5
      assert Utils.vtho_to_wei(amount) == Utils.vet_to_wei(amount)
    end
  end

  describe "wei_to_vtho/1" do
    test "converts wei to VTHO" do
      assert Utils.wei_to_vtho(100_000_000_000_000_000_000) == 100.0
    end

    test "same as wei_to_vet" do
      wei = 123_000_000_000_000_000_000
      assert Utils.wei_to_vtho(wei) == Utils.wei_to_vet(wei)
    end
  end

  describe "vet/1 and vtho/1 convenience functions" do
    test "vet/1 is alias for vet_to_wei/1" do
      assert Utils.vet(10) == Utils.vet_to_wei(10)
    end

    test "vtho/1 is alias for vtho_to_wei/1" do
      assert Utils.vtho(100) == Utils.vtho_to_wei(100)
    end
  end

  describe "generate_nonce/0" do
    test "generates integer nonce" do
      nonce = Utils.generate_nonce()
      assert is_integer(nonce)
    end

    test "generates non-negative nonce" do
      nonce = Utils.generate_nonce()
      assert nonce >= 0
    end

    test "generates unique nonces" do
      nonce1 = Utils.generate_nonce()
      nonce2 = Utils.generate_nonce()
      # Should be different (very high probability)
      assert nonce1 != nonce2
    end

    test "nonce fits in 64 bits" do
      nonce = Utils.generate_nonce()
      assert nonce < 0xFFFFFFFFFFFFFFFF
    end

    test "generates multiple unique nonces" do
      nonces = for _ <- 1..100, do: Utils.generate_nonce()
      unique_nonces = Enum.uniq(nonces)
      # All should be unique
      assert length(unique_nonces) == 100
    end
  end

  describe "block_reference/2" do
    test "creates 8-byte block reference" do
      block_id = "0x" <> String.duplicate("a", 64)
      {:ok, ref} = Utils.block_reference(12345, block_id)
      assert byte_size(ref) == 8
    end

    test "uses first 8 bytes of block hash" do
      block_hash = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32>>
      {:ok, ref} = Utils.block_reference(12345, block_hash)
      assert ref == <<1, 2, 3, 4, 5, 6, 7, 8>>
    end

    test "handles hex string block ID" do
      block_id = "0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
      {:ok, ref} = Utils.block_reference(12345, block_id)
      assert byte_size(ref) == 8
    end

    test "rejects invalid block ID" do
      assert {:error, _} = Utils.block_reference(12345, "invalid")
      assert {:error, _} = Utils.block_reference(12345, "0x1234")
    end
  end

  describe "parse_block_reference/1" do
    test "extracts block number from reference" do
      # Block number 12345 = 0x00003039
      block_ref = <<0, 0, 48, 57, 1, 2, 3, 4>>
      assert Utils.parse_block_reference(block_ref) == 12345
    end

    test "handles large block numbers" do
      # Block number 16777215 = 0x00FFFFFF
      block_ref = <<0, 255, 255, 255, 0, 0, 0, 0>>
      assert Utils.parse_block_reference(block_ref) == 16_777_215
    end

    test "handles zero block number" do
      block_ref = <<0, 0, 0, 0, 1, 2, 3, 4>>
      assert Utils.parse_block_reference(block_ref) == 0
    end
  end

  describe "integration: address handling" do
    test "full address conversion cycle" do
      # Start with binary
      original_binary = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>

      # Convert to hex
      {:ok, hex} = Utils.to_hex(original_binary)
      assert String.starts_with?(hex, "0x")

      # Convert back to binary
      {:ok, binary} = Utils.to_binary(hex)
      assert binary == original_binary

      # Generate checksum
      {:ok, checksummed} = Utils.checksum_address(hex)
      assert Utils.valid_checksum?(checksummed)

      # Verify checksummed address converts correctly
      {:ok, binary_from_checksum} = Utils.to_binary(checksummed)
      assert binary_from_checksum == original_binary
    end
  end
end
