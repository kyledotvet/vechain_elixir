defmodule VeChain.RLP.Kind.Buffer do
  @moduledoc """
  Handles encoding/decoding of raw buffer data (Uint8Array/binary).

  Buffer kind is a pass-through kind that validates the data is binary
  and returns it as-is. This is used for fields that are already in
  raw binary format, such as signatures or the reserved field arrays.

  ## Examples

      iex> alias VeChain.RLP.Kind.Buffer
      iex> {:ok, encoder} = Buffer.data(<<1, 2, 3, 4>>, "signature", [])
      iex> encoder.()
      <<1, 2, 3, 4>>

      iex> {:ok, decoder} = Buffer.buffer(<<1, 2, 3, 4>>, "signature", [])
      iex> decoder.()
      <<1, 2, 3, 4>>

      iex> Buffer.data("not a binary", "signature", [])
      {:error, "Expected binary buffer in signature, got: \"not a binary\""}
  """

  @behaviour VeChain.RLP.Kind

  @impl true
  def data(data, context, opts \\ [])

  def data(data, _context, _opts) when is_binary(data) do
    # Data is already a buffer, return as-is
    {:ok, fn -> data end}
  end

  def data(data, context, _opts) do
    {:error, "Expected binary buffer in #{context}, got: #{inspect(data)}"}
  end

  @impl true
  def buffer(buffer, context, opts \\ [])

  def buffer(buffer, _context, _opts) when is_binary(buffer) do
    # Buffer is already in correct format, return as-is
    {:ok, fn -> buffer end}
  end

  def buffer(buffer, context, _opts) do
    {:error, "Expected binary buffer in #{context}, got: #{inspect(buffer)}"}
  end
end
