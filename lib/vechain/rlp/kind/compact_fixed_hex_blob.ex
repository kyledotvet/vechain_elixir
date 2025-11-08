defmodule VeChain.RLP.Kind.CompactFixedHexBlob do
  @moduledoc """
  Handles encoding/decoding of compact fixed-size hex blobs.

  This kind is used for fixed-size fields that should have leading zeros
  removed during encoding (for compact RLP representation) and restored
  during decoding. Common use case is block references.

  ## Options

  - `:bytes` - Required fixed byte size for the full (padded) value

  ## Examples

      # Block reference: 8 bytes, but leading zeros removed for encoding
      iex> alias VeChain.RLP.Kind.CompactFixedHexBlob
      iex> {:ok, encoder} = CompactFixedHexBlob.data("0x00000000aabbccdd", "blockRef", bytes: 8)
      iex> encoder.()  # Leading zeros removed
      <<0xaa, 0xbb, 0xcc, 0xdd>>

      # Decoding pads back to full size
      iex> {:ok, decoder} = CompactFixedHexBlob.buffer(<<0xaa, 0xbb, 0xcc, 0xdd>>, "blockRef", bytes: 8)
      iex> decoder.()
      "0x00000000aabbccdd"

      # All zeros becomes single zero byte
      iex> {:ok, encoder} = CompactFixedHexBlob.data("0x0000000000000000", "blockRef", bytes: 8)
      iex> encoder.()
      <<0>>
  """

  @behaviour VeChain.RLP.Kind

  alias VeChain.RLP.Kind.HexBlob

  @impl true
  def data(data, context, opts) do
    _bytes = Keyword.fetch!(opts, :bytes)

    with {:ok, encoder} <- HexBlob.data(data, context, opts) do
      # Wrap encoder to remove leading zeros
      compact_encoder = fn ->
        encoded = encoder.()
        # Remove leading zeros but keep at least one byte
        trim_leading_zeros(encoded)
      end

      {:ok, compact_encoder}
    end
  end

  @impl true
  def buffer(buffer, context, opts) do
    bytes = Keyword.fetch!(opts, :bytes)

    with {:ok, decoder} <- HexBlob.buffer(buffer, context, opts) do
      # Wrap decoder to pad with leading zeros
      padded_decoder = fn ->
        decoded = decoder.()
        hex_str = String.trim_leading(decoded, "0x")

        # Pad to expected length
        expected_length = bytes * 2
        actual_length = String.length(hex_str)

        if actual_length < expected_length do
          padding = String.duplicate("0", expected_length - actual_length)
          "0x" <> padding <> hex_str
        else
          decoded
        end
      end

      {:ok, padded_decoder}
    end
  end

  # Private functions

  # Remove leading zero bytes, but always keep at least one byte
  defp trim_leading_zeros(<<0, rest::binary>>) when byte_size(rest) > 0 do
    trim_leading_zeros(rest)
  end

  defp trim_leading_zeros(binary), do: binary
end
