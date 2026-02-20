defmodule VeChain.Transaction.ValidationTest do
  use ExUnit.Case, async: true

  alias VeChain.Transaction.Validation

  describe "block_ref/1" do
    test "accepts 8-byte binary block_ref" do
      config = %{block_ref: <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08>>}

      result = Validation.block_ref(config)

      assert result == config
      assert byte_size(result.block_ref) == 8
    end

    test "accepts hex-encoded block_ref string with 0x prefix" do
      config = %{block_ref: "0x0102030405060708"}

      result = Validation.block_ref(config)

      assert result.block_ref == <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08>>
      assert byte_size(result.block_ref) == 8
    end

    test "accepts hex-encoded block_ref with uppercase letters" do
      config = %{block_ref: "0xFFEEDDCCBBAA9988"}

      result = Validation.block_ref(config)

      assert result.block_ref == <<0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88>>
    end

    test "accepts hex-encoded block_ref with mixed case" do
      config = %{block_ref: "0xAbCdEf0123456789"}

      result = Validation.block_ref(config)

      assert byte_size(result.block_ref) == 8
    end

    test "preserves other config fields" do
      config = %{
        block_ref: <<0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88>>,
        chain_tag: <<0x4A>>,
        nonce: <<1, 2, 3>>
      }

      result = Validation.block_ref(config)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == <<1, 2, 3>>
      assert result.block_ref == <<0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88>>
    end

    test "raises ArgumentError for block_ref with less than 8 bytes" do
      config = %{block_ref: <<0x01, 0x02, 0x03>>}

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     Validation.block_ref(config)
                   end
    end

    test "raises ArgumentError for hex block_ref with less than 8 bytes" do
      config = %{block_ref: "0x010203"}

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     Validation.block_ref(config)
                   end
    end

    test "raises ArgumentError for block_ref with more than 8 bytes" do
      config = %{block_ref: <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09>>}

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     Validation.block_ref(config)
                   end
    end

    test "raises ArgumentError for hex block_ref with more than 8 bytes" do
      config = %{block_ref: "0x010203040506070809"}

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     Validation.block_ref(config)
                   end
    end

    test "raises ArgumentError for empty block_ref" do
      config = %{block_ref: <<>>}

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     Validation.block_ref(config)
                   end
    end

    test "raises ArgumentError for missing block_ref" do
      config = %{}

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     Validation.block_ref(config)
                   end
    end

    test "raises ArgumentError for non-binary block_ref" do
      config = %{block_ref: 12345}

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     Validation.block_ref(config)
                   end
    end
  end

  describe "expiration/1" do
    test "accepts positive integer expiration" do
      config = %{expiration: 100}

      result = Validation.expiration(config)

      assert result.expiration == :binary.encode_unsigned(100)
      assert is_binary(result.expiration)
    end

    test "accepts 1 as minimum valid expiration" do
      config = %{expiration: 1}

      result = Validation.expiration(config)

      assert result.expiration == :binary.encode_unsigned(1)
      assert result.expiration == <<1>>
    end

    test "accepts maximum 4-byte expiration value" do
      config = %{expiration: 0xFFFFFFFF}

      result = Validation.expiration(config)

      assert byte_size(result.expiration) == 4
    end

    test "converts small integer to 1-byte binary" do
      config = %{expiration: 255}

      result = Validation.expiration(config)

      assert result.expiration == <<255>>
    end

    test "converts larger integer to multi-byte binary" do
      config = %{expiration: 65535}

      result = Validation.expiration(config)

      assert result.expiration == <<255, 255>>
    end

    test "preserves other config fields" do
      config = %{
        expiration: 50,
        chain_tag: <<0x4A>>,
        nonce: <<1, 2, 3>>
      }

      result = Validation.expiration(config)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == <<1, 2, 3>>
      assert result.expiration == :binary.encode_unsigned(50)
    end

    test "raises ArgumentError for zero expiration" do
      config = %{expiration: 0}

      assert_raise ArgumentError, "Expiration must be a positive integer", fn ->
        Validation.expiration(config)
      end
    end

    test "raises ArgumentError for negative expiration" do
      config = %{expiration: -1}

      assert_raise ArgumentError, "Expiration must be a positive integer", fn ->
        Validation.expiration(config)
      end
    end

    test "raises ArgumentError for expiration exceeding 4 bytes" do
      config = %{expiration: 0x100000000}

      assert_raise ArgumentError,
                   "Expiration must be a positive integer of up to 4 bytes (< 2^32)",
                   fn ->
                     Validation.expiration(config)
                   end
    end

    test "raises ArgumentError for missing expiration" do
      config = %{}

      assert_raise ArgumentError, "Expiration must be a positive integer", fn ->
        Validation.expiration(config)
      end
    end

    test "raises ArgumentError for non-integer expiration" do
      config = %{expiration: "100"}

      assert_raise ArgumentError, "Expiration must be a positive integer", fn ->
        Validation.expiration(config)
      end
    end
  end

  describe "gas_fields/2 with :eip_1559" do
    test "accepts valid max_priority_fee_per_gas and max_fee_per_gas" do
      config = %{
        max_priority_fee_per_gas: 1000,
        max_fee_per_gas: 2000
      }

      result = Validation.gas_fields(config, :eip_1559)

      assert is_binary(result.max_priority_fee_per_gas)
      assert is_binary(result.max_fee_per_gas)
      assert result.max_priority_fee_per_gas == :binary.encode_unsigned(1000)
      assert result.max_fee_per_gas == :binary.encode_unsigned(2000)
    end

    test "accepts zero values for gas fields" do
      config = %{
        max_priority_fee_per_gas: 0,
        max_fee_per_gas: 0
      }

      result = Validation.gas_fields(config, :eip_1559)

      assert result.max_priority_fee_per_gas == :binary.encode_unsigned(0)
      assert result.max_fee_per_gas == :binary.encode_unsigned(0)
    end

    test "accepts maximum 32-byte values for gas fields" do
      max_value = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

      config = %{
        max_priority_fee_per_gas: max_value,
        max_fee_per_gas: max_value
      }

      result = Validation.gas_fields(config, :eip_1559)

      assert byte_size(result.max_priority_fee_per_gas) == 32
      assert byte_size(result.max_fee_per_gas) == 32
    end

    test "preserves other config fields" do
      config = %{
        max_priority_fee_per_gas: 1000,
        max_fee_per_gas: 2000,
        chain_tag: <<0x4A>>,
        nonce: <<1, 2, 3>>
      }

      result = Validation.gas_fields(config, :eip_1559)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == <<1, 2, 3>>
    end

    test "raises ArgumentError for negative max_priority_fee_per_gas" do
      config = %{
        max_priority_fee_per_gas: -1,
        max_fee_per_gas: 2000
      }

      assert_raise ArgumentError,
                   "max_priority_fee_per_gas must be a non-negative integer of up to 32 bytes (< 2^256)",
                   fn ->
                     Validation.gas_fields(config, :eip_1559)
                   end
    end

    test "raises ArgumentError for negative max_fee_per_gas" do
      config = %{
        max_priority_fee_per_gas: 1000,
        max_fee_per_gas: -1
      }

      assert_raise ArgumentError,
                   "max_fee_per_gas must be a non-negative integer of up to 32 bytes (< 2^256)",
                   fn ->
                     Validation.gas_fields(config, :eip_1559)
                   end
    end

    test "raises ArgumentError for max_priority_fee_per_gas exceeding 32 bytes" do
      # 2^256
      too_large = 0x10000000000000000000000000000000000000000000000000000000000000000

      config = %{
        max_priority_fee_per_gas: too_large,
        max_fee_per_gas: 2000
      }

      assert_raise ArgumentError,
                   "max_priority_fee_per_gas must be a non-negative integer of up to 32 bytes (< 2^256)",
                   fn ->
                     Validation.gas_fields(config, :eip_1559)
                   end
    end

    test "raises ArgumentError for max_fee_per_gas exceeding 32 bytes" do
      # 2^256
      too_large = 0x10000000000000000000000000000000000000000000000000000000000000000

      config = %{
        max_priority_fee_per_gas: 1000,
        max_fee_per_gas: too_large
      }

      assert_raise ArgumentError,
                   "max_fee_per_gas must be a non-negative integer of up to 32 bytes (< 2^256)",
                   fn ->
                     Validation.gas_fields(config, :eip_1559)
                   end
    end

    test "raises ArgumentError for missing max_priority_fee_per_gas" do
      config = %{max_fee_per_gas: 2000}

      assert_raise ArgumentError,
                   "max_priority_fee_per_gas must be a non-negative integer of up to 32 bytes (< 2^256)",
                   fn ->
                     Validation.gas_fields(config, :eip_1559)
                   end
    end

    test "raises ArgumentError for missing max_fee_per_gas" do
      config = %{max_priority_fee_per_gas: 1000}

      assert_raise ArgumentError,
                   "max_fee_per_gas must be a non-negative integer of up to 32 bytes (< 2^256)",
                   fn ->
                     Validation.gas_fields(config, :eip_1559)
                   end
    end

    test "raises ArgumentError for non-integer max_priority_fee_per_gas" do
      config = %{
        max_priority_fee_per_gas: "1000",
        max_fee_per_gas: 2000
      }

      assert_raise ArgumentError,
                   "max_priority_fee_per_gas must be a non-negative integer of up to 32 bytes (< 2^256)",
                   fn ->
                     Validation.gas_fields(config, :eip_1559)
                   end
    end

    test "raises ArgumentError for non-integer max_fee_per_gas" do
      config = %{
        max_priority_fee_per_gas: 1000,
        max_fee_per_gas: "2000"
      }

      assert_raise ArgumentError,
                   "max_fee_per_gas must be a non-negative integer of up to 32 bytes (< 2^256)",
                   fn ->
                     Validation.gas_fields(config, :eip_1559)
                   end
    end
  end

  describe "gas_fields/2 with :legacy" do
    test "accepts valid gas_price_coef" do
      config = %{gas_price_coef: 128}

      result = Validation.gas_fields(config, :legacy)

      assert result.gas_price_coef == :binary.encode_unsigned(128)
      assert is_binary(result.gas_price_coef)
    end

    test "accepts zero as gas_price_coef" do
      config = %{gas_price_coef: 0}

      result = Validation.gas_fields(config, :legacy)

      assert result.gas_price_coef == :binary.encode_unsigned(0)
    end

    test "accepts maximum value 255 for gas_price_coef" do
      config = %{gas_price_coef: 255}

      result = Validation.gas_fields(config, :legacy)

      assert result.gas_price_coef == <<255>>
    end

    test "preserves other config fields" do
      config = %{
        gas_price_coef: 128,
        chain_tag: <<0x4A>>,
        nonce: <<1, 2, 3>>
      }

      result = Validation.gas_fields(config, :legacy)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == <<1, 2, 3>>
      assert result.gas_price_coef == :binary.encode_unsigned(128)
    end

    test "raises ArgumentError for gas_price_coef greater than 255" do
      config = %{gas_price_coef: 256}

      assert_raise FunctionClauseError, fn ->
        Validation.gas_fields(config, :legacy)
      end
    end

    test "raises ArgumentError for negative gas_price_coef" do
      config = %{gas_price_coef: -1}

      assert_raise FunctionClauseError, fn ->
        Validation.gas_fields(config, :legacy)
      end
    end

    test "raises ArgumentError for missing gas_price_coef" do
      config = %{}

      assert_raise FunctionClauseError, fn ->
        Validation.gas_fields(config, :legacy)
      end
    end

    test "raises ArgumentError for non-integer gas_price_coef" do
      config = %{gas_price_coef: "128"}

      assert_raise FunctionClauseError, fn ->
        Validation.gas_fields(config, :legacy)
      end
    end
  end

  describe "nonce/1" do
    test "accepts positive integer nonce" do
      config = %{nonce: 12345}

      result = Validation.nonce(config)

      assert result.nonce == :binary.encode_unsigned(12345)
      assert is_binary(result.nonce)
    end

    test "accepts zero as a valid nonce" do
      config = %{nonce: 0}

      result = Validation.nonce(config)

      assert result.nonce == :binary.encode_unsigned(0)
    end

    test "accepts maximum 8-byte nonce value" do
      config = %{nonce: 0xFFFFFFFFFFFFFFFF}

      result = Validation.nonce(config)

      assert byte_size(result.nonce) == 8
    end

    test "converts small integer to 1-byte binary" do
      config = %{nonce: 255}

      result = Validation.nonce(config)

      assert result.nonce == <<255>>
    end

    test "converts larger integer to multi-byte binary" do
      config = %{nonce: 65535}

      result = Validation.nonce(config)

      assert result.nonce == <<255, 255>>
    end

    test "preserves other config fields" do
      config = %{
        nonce: 100,
        chain_tag: <<0x4A>>,
        block_ref: <<1, 2, 3, 4, 5, 6, 7, 8>>
      }

      result = Validation.nonce(config)

      assert result.chain_tag == <<0x4A>>
      assert result.block_ref == <<1, 2, 3, 4, 5, 6, 7, 8>>
      assert result.nonce == :binary.encode_unsigned(100)
    end

    test "raises ArgumentError for negative nonce" do
      config = %{nonce: -1}

      assert_raise ArgumentError,
                   "Nonce must be a non-negative integer of up to 8 bytes (< 2^64)",
                   fn ->
                     Validation.nonce(config)
                   end
    end

    test "raises ArgumentError for nonce exceeding 8 bytes" do
      config = %{nonce: 0x10000000000000000}

      assert_raise ArgumentError,
                   "Nonce must be a non-negative integer of up to 8 bytes (< 2^64)",
                   fn ->
                     Validation.nonce(config)
                   end
    end

    test "raises ArgumentError for missing nonce" do
      config = %{}

      assert_raise ArgumentError,
                   "Nonce must be a non-negative integer of up to 8 bytes (< 2^64)",
                   fn ->
                     Validation.nonce(config)
                   end
    end

    test "raises ArgumentError for non-integer nonce" do
      config = %{nonce: "12345"}

      assert_raise ArgumentError,
                   "Nonce must be a non-negative integer of up to 8 bytes (< 2^64)",
                   fn ->
                     Validation.nonce(config)
                   end
    end
  end

  describe "depends_on/1" do
    test "accepts nil depends_on" do
      config = %{depends_on: nil}

      result = Validation.depends_on(config)

      assert result.depends_on == <<>>
    end

    test "accepts 32-byte binary depends_on" do
      tx_id = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32>>
      config = %{depends_on: tx_id}

      result = Validation.depends_on(config)

      assert result == config
      assert byte_size(result.depends_on) == 32
    end

    test "accepts hex-encoded depends_on string with 0x prefix" do
      tx_id_hex = "0x" <> String.duplicate("a", 64)
      config = %{depends_on: tx_id_hex}

      result = Validation.depends_on(config)

      assert is_binary(result.depends_on)
      assert byte_size(result.depends_on) == 32
    end

    test "accepts hex-encoded depends_on with uppercase letters" do
      tx_id_hex = "0x" <> String.duplicate("F", 64)
      config = %{depends_on: tx_id_hex}

      result = Validation.depends_on(config)

      assert byte_size(result.depends_on) == 32
    end

    test "accepts hex-encoded depends_on with mixed case" do
      tx_id_hex = "0x" <> String.duplicate("aB", 32)
      config = %{depends_on: tx_id_hex}

      result = Validation.depends_on(config)

      assert byte_size(result.depends_on) == 32
    end

    test "preserves other config fields with nil depends_on" do
      config = %{
        depends_on: nil,
        chain_tag: <<0x4A>>,
        nonce: <<1, 2, 3>>
      }

      result = Validation.depends_on(config)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == <<1, 2, 3>>
      assert result.depends_on == <<>>
    end

    test "preserves other config fields with binary depends_on" do
      tx_id = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32>>
      config = %{
        depends_on: tx_id,
        chain_tag: <<0x4A>>,
        nonce: <<1, 2, 3>>
      }

      result = Validation.depends_on(config)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == <<1, 2, 3>>
      assert result.depends_on == tx_id
    end

    test "raises ArgumentError for depends_on with less than 32 bytes" do
      config = %{depends_on: <<1, 2, 3>>}

      assert_raise ArgumentError,
                   "depends_on must be nil or a binary string of 32 bytes (64 hex characters) representing a transaction ID",
                   fn ->
                     Validation.depends_on(config)
                   end
    end

    test "raises ArgumentError for hex depends_on with less than 32 bytes" do
      config = %{depends_on: "0x010203"}

      assert_raise ArgumentError,
                   "depends_on must be nil or a binary string of 32 bytes (64 hex characters) representing a transaction ID",
                   fn ->
                     Validation.depends_on(config)
                   end
    end

    test "raises ArgumentError for depends_on with more than 32 bytes" do
      config = %{depends_on: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33>>}

      assert_raise ArgumentError,
                   "depends_on must be nil or a binary string of 32 bytes (64 hex characters) representing a transaction ID",
                   fn ->
                     Validation.depends_on(config)
                   end
    end

    test "raises ArgumentError for hex depends_on with more than 32 bytes" do
      config = %{depends_on: "0x" <> String.duplicate("a", 66)}

      assert_raise ArgumentError,
                   "depends_on must be nil or a binary string of 32 bytes (64 hex characters) representing a transaction ID",
                   fn ->
                     Validation.depends_on(config)
                   end
    end

    test "raises ArgumentError for empty depends_on" do
      config = %{depends_on: <<>>}

      assert_raise ArgumentError,
                   "depends_on must be nil or a binary string of 32 bytes (64 hex characters) representing a transaction ID",
                   fn ->
                     Validation.depends_on(config)
                   end
    end

    test "raises ArgumentError for non-binary depends_on" do
      config = %{depends_on: 12345}

      assert_raise ArgumentError,
                   "depends_on must be nil or a binary string of 32 bytes (64 hex characters) representing a transaction ID",
                   fn ->
                     Validation.depends_on(config)
                   end
    end

    test "raises ArgumentError for invalid hex string" do
      config = %{depends_on: "0xinvalidhex"}

      assert_raise ArgumentError, fn ->
        Validation.depends_on(config)
      end
    end
  end
end
