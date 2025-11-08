defmodule VeChain.RLP.Kind.HexBlob do
  @moduledoc """
  Handles encoding/decoding of hex blob data (0x-prefixed hex strings).

  Hex blobs are variable-length hex-encoded binary data. During encoding,
  the hex string is decoded to bytes. During decoding, bytes are encoded
  back to a hex string with 0x prefix.

  ## Examples

      iex> alias VeChain.RLP.Kind.HexBlob
      iex> {:ok, encoder} = HexBlob.data("0x1234", "test", [])
      iex> encoder.()
      <<0x12, 0x34>>

      iex> {:ok, decoder} = HexBlob.buffer(<<0x12, 0x34>>, "test", [])
      iex> decoder.()
      "0x1234"

      iex> HexBlob.data("1234", "test", [])
      {:error, "Hex blob must start with 0x in test"}

      iex> HexBlob.data("0x123", "test", [])
      {:error, "Hex blob must have even length in test"}
  """

  @behaviour VeChain.RLP.Kind

  @impl true
  def data(data, context, _opts \\ []) do
    with :ok <- assert_valid_hex_blob(data, context) do
      # Remove "0x" prefix and decode
      hex_str = String.trim_leading(data, "0x")

      case Base.decode16(hex_str, case: :mixed) do
        {:ok, bytes} ->
          {:ok, fn -> bytes end}

        :error ->
          {:error, "Invalid hex encoding in #{context}"}
      end
    end
  end

  @impl true
  def buffer(buffer, _context, _opts \\ []) when is_binary(buffer) do
    # Encode buffer to hex string with 0x prefix
    hex_str = "0x" <> Base.encode16(buffer, case: :lower)
    {:ok, fn -> hex_str end}
  end

  # Private functions

  defp assert_valid_hex_blob(data, context) when is_binary(data) do
    cond do
      not String.starts_with?(data, "0x") ->
        {:error, "Hex blob must start with 0x in #{context}"}

      rem(String.length(data) - 2, 2) != 0 ->
        {:error, "Hex blob must have even length in #{context}"}

      true ->
        :ok
    end
  end

  defp assert_valid_hex_blob(data, context) do
    {:error, "Expected hex blob string in #{context}, got: #{inspect(data)}"}
  end
end
