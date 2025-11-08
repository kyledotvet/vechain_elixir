defmodule VeChain.RLP.Kind.FixedHexBlob do
  @moduledoc """
  Handles encoding/decoding of fixed-size hex blobs (e.g., addresses, hashes).

  Fixed hex blobs must have an exact byte length. Common uses include:
  - Addresses: 20 bytes (40 hex chars + "0x" prefix)
  - Hashes: 32 bytes (64 hex chars + "0x" prefix)

  ## Options

  - `:bytes` - Required exact byte size (e.g., 20 for addresses, 32 for hashes)

  ## Examples

      # 20-byte address
      iex> alias VeChain.RLP.Kind.FixedHexBlob
      iex> address = "0x" <> String.duplicate("ab", 20)
      iex> {:ok, encoder} = FixedHexBlob.data(address, "address", bytes: 20)
      iex> byte_size(encoder.())
      20

      # Wrong size
      iex> FixedHexBlob.data("0x1234", "address", bytes: 20)
      {:error, "Expected 20 bytes in address, got 2"}

      # Decode
      iex> {:ok, decoder} = FixedHexBlob.buffer(<<0xab::160>>, "address", bytes: 20)
      iex> String.length(decoder.()) - 2  # -2 for "0x" prefix
      40
  """

  @behaviour VeChain.RLP.Kind

  alias VeChain.RLP.Kind.HexBlob

  @impl true
  def data(data, context, opts) do
    bytes = Keyword.fetch!(opts, :bytes)

    with {:ok, encoder} <- HexBlob.data(data, context, opts),
         :ok <- assert_fixed_size(data, context, bytes) do
      {:ok, encoder}
    end
  end

  @impl true
  def buffer(buffer, context, opts) do
    bytes = Keyword.fetch!(opts, :bytes)

    with :ok <- assert_buffer_size(buffer, context, bytes),
         {:ok, decoder} <- HexBlob.buffer(buffer, context, opts) do
      {:ok, decoder}
    end
  end

  # Private functions

  defp assert_fixed_size(data, context, expected_bytes) when is_binary(data) do
    # Remove 0x prefix and check length
    hex_str = String.trim_leading(data, "0x")
    actual_bytes = div(String.length(hex_str), 2)

    if actual_bytes == expected_bytes do
      :ok
    else
      {:error, "Expected #{expected_bytes} bytes in #{context}, got #{actual_bytes}"}
    end
  end

  defp assert_buffer_size(buffer, context, expected_bytes) when is_binary(buffer) do
    if byte_size(buffer) == expected_bytes do
      :ok
    else
      {:error, "Expected #{expected_bytes} bytes in #{context}, got #{byte_size(buffer)}"}
    end
  end
end
