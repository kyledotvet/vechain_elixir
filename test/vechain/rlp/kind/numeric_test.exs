defmodule VeChain.RLP.Kind.NumericTest do
  use ExUnit.Case, async: true

  alias VeChain.RLP.Kind.Numeric

  describe "data/3" do
    test "encodes integer to bytes" do
      {:ok, encoder} = Numeric.data(1000, "test", [])
      assert encoder.() == <<0x03, 0xE8>>
    end

    test "encodes zero to empty bytes" do
      {:ok, encoder} = Numeric.data(0, "test", [])
      assert encoder.() == <<>>
    end

    test "respects max_bytes constraint" do
      {:ok, encoder} = Numeric.data(255, "test", max_bytes: 1)
      assert encoder.() == <<0xFF>>
    end

    test "errors when exceeding max_bytes" do
      {:error, msg} = Numeric.data(256, "test", max_bytes: 1)
      assert msg =~ "exceeds max_bytes"
    end

    test "parses hex strings" do
      {:ok, encoder} = Numeric.data("0x3e8", "test", [])
      assert encoder.() == <<0x03, 0xE8>>
    end

    test "parses hex strings without 0x prefix" do
      {:ok, encoder} = Numeric.data("3e8", "test", [])
      assert encoder.() == <<0x03, 0xE8>>
    end

    test "errors on negative integers" do
      {:error, msg} = Numeric.data(-1, "test", [])
      assert msg =~ "Expected numeric value"
    end

    test "errors on invalid hex strings" do
      {:error, msg} = Numeric.data("0xgg", "test", [])
      assert msg =~ "Invalid numeric data"
    end

    test "errors on non-numeric values" do
      {:error, msg} = Numeric.data("not_a_number", "test", [])
      assert msg =~ "Invalid numeric data"
    end
  end

  describe "buffer/3" do
    test "decodes bytes to integer" do
      {:ok, decoder} = Numeric.buffer(<<0x03, 0xE8>>, "test", [])
      assert decoder.() == 1000
    end

    test "decodes empty bytes to zero" do
      {:ok, decoder} = Numeric.buffer(<<>>, "test", [])
      assert decoder.() == 0
    end

    test "decodes single byte" do
      {:ok, decoder} = Numeric.buffer(<<0xFF>>, "test", [])
      assert decoder.() == 255
    end

    test "respects max_bytes constraint" do
      {:ok, decoder} = Numeric.buffer(<<0xFF>>, "test", max_bytes: 1)
      assert decoder.() == 255
    end

    test "errors when buffer exceeds max_bytes" do
      {:error, msg} = Numeric.buffer(<<0x01, 0x00>>, "test", max_bytes: 1)
      assert msg =~ "exceeds max_bytes"
    end

    test "decodes large numbers" do
      # 2^32 = 4294967296
      {:ok, decoder} = Numeric.buffer(<<0x01, 0x00, 0x00, 0x00, 0x00>>, "test", [])
      assert decoder.() == 4_294_967_296
    end
  end

  describe "roundtrip" do
    test "encodes and decodes to same value" do
      values = [0, 1, 127, 128, 255, 256, 1000, 65535, 1_000_000]

      for value <- values do
        {:ok, encoder} = Numeric.data(value, "test", [])
        encoded = encoder.()

        {:ok, decoder} = Numeric.buffer(encoded, "test", [])
        decoded = decoder.()

        assert decoded == value, "Failed for value #{value}"
      end
    end

    test "hex strings roundtrip" do
      {:ok, encoder} = Numeric.data("0xabcdef", "test", [])
      encoded = encoder.()

      {:ok, decoder} = Numeric.buffer(encoded, "test", [])
      decoded = decoder.()

      assert decoded == 0xABCDEF
    end
  end
end
