defmodule VeChain.RLP.Kind.Numeric do
  @moduledoc """
  Handles encoding/decoding of numeric values (integers and bigints).

  Numeric values are encoded as big-endian bytes with leading zeros removed.
  Zero is encoded as an empty byte array. Supports optional `max_bytes` constraint.

  ## Options

  - `:max_bytes` - Maximum number of bytes for the encoded value (optional)

  ## Examples

      iex> alias VeChain.RLP.Kind.Numeric
      iex> {:ok, encoder} = Numeric.data(1000, "test", [])
      iex> encoder.()
      <<0x03, 0xe8>>

      iex> {:ok, decoder} = Numeric.buffer(<<0x03, 0xe8>>, "test", [])
      iex> decoder.()
      1000

      iex> {:ok, encoder} = Numeric.data(0, "test", [])
      iex> encoder.()
      <<>>

      iex> {:ok, encoder} = Numeric.data(255, "test", max_bytes: 1)
      iex> encoder.()
      <<0xff>>

      iex> Numeric.data(256, "test", max_bytes: 1)
      {:error, "Numeric value exceeds max_bytes (1) in test"}
  """

  @behaviour VeChain.RLP.Kind

  @impl true
  def data(data, context, opts \\ []) do
    max_bytes = Keyword.get(opts, :max_bytes)

    with {:ok, bigint} <- validate_numeric(data, context),
         {:ok, encoded} <- encode_bigint(bigint, max_bytes, context) do
      # Return lazy encoder
      {:ok, fn -> encoded end}
    end
  end

  @impl true
  def buffer(buffer, context, opts \\ []) do
    max_bytes = Keyword.get(opts, :max_bytes)

    with :ok <- assert_valid_buffer(buffer, context, max_bytes),
         {:ok, decoded} <- decode_buffer_to_number(buffer) do
      # Return lazy decoder
      {:ok, fn -> decoded end}
    end
  end

  # Private functions

  # Validate numeric data - accept integers and hex strings
  defp validate_numeric(data, _context) when is_integer(data) and data >= 0 do
    {:ok, data}
  end

  defp validate_numeric(data, context) when is_binary(data) do
    # Parse hex string "0x..." to integer
    hex_str = String.trim_leading(data, "0x")

    case Integer.parse(hex_str, 16) do
      {int, ""} when int >= 0 -> {:ok, int}
      _ -> {:error, "Invalid numeric data in #{context}: #{inspect(data)}"}
    end
  end

  defp validate_numeric(data, context) do
    {:error, "Expected numeric value in #{context}, got: #{inspect(data)}"}
  end

  # Encode bigint to buffer with optional max_bytes constraint
  # Zero is encoded as empty buffer (per RLP spec)
  defp encode_bigint(0, _max_bytes, _context) do
    {:ok, <<>>}
  end

  defp encode_bigint(int, nil, _context) when int > 0 do
    # Minimal byte encoding (remove leading zeros)
    bytes = :binary.encode_unsigned(int, :big)
    {:ok, bytes}
  end

  defp encode_bigint(int, max_bytes, context) when int > 0 do
    bytes = :binary.encode_unsigned(int, :big)

    if byte_size(bytes) <= max_bytes do
      {:ok, bytes}
    else
      {:error, "Numeric value exceeds max_bytes (#{max_bytes}) in #{context}"}
    end
  end

  # Validate buffer size if max_bytes is specified
  defp assert_valid_buffer(_buffer, _context, nil), do: :ok

  defp assert_valid_buffer(buffer, context, max_bytes) do
    if byte_size(buffer) <= max_bytes do
      :ok
    else
      {:error, "Buffer exceeds max_bytes (#{max_bytes}) in #{context}"}
    end
  end

  # Decode buffer to number
  # Empty buffer decodes to 0
  defp decode_buffer_to_number(<<>>) do
    {:ok, 0}
  end

  defp decode_buffer_to_number(buffer) when is_binary(buffer) do
    # Decode unsigned big-endian integer
    # Note: RLP should already have leading zeros removed
    decoded = :binary.decode_unsigned(buffer, :big)
    {:ok, decoded}
  end
end
