defmodule VeChain.RLP.Kind.OptionalFixedHexBlob do
  @moduledoc """
  Handles encoding/decoding of optional fixed-size hex blobs.

  This kind allows empty/nil values for fields that may not be present.
  When the value is nil, empty string, or "0x", it encodes to an empty buffer.
  Common use case is the `depends_on` field in transactions.

  ## Options

  - `:bytes` - Required fixed byte size when value is present

  ## Examples

      iex> alias VeChain.RLP.Kind.OptionalFixedHexBlob
      # Nil encodes to empty buffer
      iex> {:ok, encoder} = OptionalFixedHexBlob.data(nil, "dependsOn", bytes: 32)
      iex> encoder.()
      <<>>

      # Empty string encodes to empty buffer
      iex> {:ok, encoder} = OptionalFixedHexBlob.data("", "dependsOn", bytes: 32)
      iex> encoder.()
      <<>>

      # "0x" encodes to empty buffer
      iex> {:ok, encoder} = OptionalFixedHexBlob.data("0x", "dependsOn", bytes: 32)
      iex> encoder.()
      <<>>

      # Valid value encodes normally
      iex> hash = "0x" <> String.duplicate("ab", 32)
      iex> {:ok, encoder} = OptionalFixedHexBlob.data(hash, "dependsOn", bytes: 32)
      iex> byte_size(encoder.())
      32

      # Empty buffer decodes to empty string
      iex> {:ok, decoder} = OptionalFixedHexBlob.buffer(<<>>, "dependsOn", bytes: 32)
      iex> decoder.()
      ""
  """

  @behaviour VeChain.RLP.Kind

  alias VeChain.RLP.Kind.FixedHexBlob

  @impl true
  def data(data, _context, _opts) when data in [nil, "", "0x"] do
    # Return empty buffer for nil/empty values
    {:ok, fn -> <<>> end}
  end

  def data(data, context, opts) do
    FixedHexBlob.data(data, context, opts)
  end

  @impl true
  def buffer(buffer, _context, _opts) when byte_size(buffer) == 0 do
    # Return empty string for empty buffer
    {:ok, fn -> "" end}
  end

  def buffer(buffer, context, opts) do
    FixedHexBlob.buffer(buffer, context, opts)
  end
end
