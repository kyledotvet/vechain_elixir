defmodule VeChain.RLP do
  @moduledoc """
  RLP (Recursive Length Prefix) encoding and decoding for VeChain.

  VeChain uses RLP encoding for transaction serialization, the same as Ethereum.
  This module provides a clean interface around the `ex_rlp` library with
  VeChain-specific conveniences.

  ## Examples

      # Encode simple values
      iex> VeChain.RLP.encode(1)
      <<1>>

      iex> VeChain.RLP.encode("hello")
      <<133, 104, 101, 108, 108, 111>>

      # Encode lists (nested structures)
      iex> VeChain.RLP.encode([1, [2, 3]])
      <<196, 1, 194, 2, 3>>

      # Decode
      iex> VeChain.RLP.decode(<<1>>)
      1

      iex> VeChain.RLP.decode(<<133, 104, 101, 108, 108, 111>>)
      "hello"

  ## RLP Encoding Rules

  RLP encoding follows these rules:

  1. For a single byte with value [0x00, 0x7f], it's encoded as itself
  2. For strings 0-55 bytes long, the encoding consists of a single byte with
     value 0x80 + length followed by the string
  3. For strings longer than 55 bytes, the encoding consists of a single byte
     with value 0xb7 + length of the length, followed by the length, followed
     by the string
  4. For lists, similar rules apply but starting at 0xc0

  ## Type Handling

  - Integers: Encoded as big-endian binary
  - Strings/Binaries: Encoded directly
  - Lists: Recursively encode each element
  - Empty values: Encoded as 0x80
  """

  @doc """
  Encodes a value using RLP encoding.

  ## Parameters

    * `value` - The value to encode. Can be:
      - Integer (encoded as big-endian binary)
      - Binary string
      - List (recursively encoded)

  ## Returns

  The RLP-encoded binary.

  ## Examples

      iex> VeChain.RLP.encode(0)
      <<128>>

      iex> VeChain.RLP.encode(127)
      <<127>>

      iex> VeChain.RLP.encode(128)
      <<129, 128>>

      iex> VeChain.RLP.encode("dog")
      <<131, 100, 111, 103>>

      iex> VeChain.RLP.encode(["cat", "dog"])
      <<200, 131, 99, 97, 116, 131, 100, 111, 103>>
  """
  @spec encode(term()) :: binary()
  def encode(value) do
    ExRLP.encode(value)
  end

  @doc """
  Decodes an RLP-encoded binary.

  ## Parameters

    * `data` - The RLP-encoded binary to decode

  ## Returns

  The decoded value. Types are decoded as follows:
  - Single bytes become integers
  - Byte sequences become binaries
  - Lists become Elixir lists

  ## Examples

      iex> VeChain.RLP.decode(<<128>>)
      ""

      iex> VeChain.RLP.decode(<<127>>)
      127

      iex> VeChain.RLP.decode(<<131, 100, 111, 103>>)
      "dog"

      iex> VeChain.RLP.decode(<<200, 131, 99, 97, 116, 131, 100, 111, 103>>)
      ["cat", "dog"]
  """
  @spec decode(binary()) :: term()
  def decode(data) when is_binary(data) do
    data
    |> ExRLP.decode()
    |> normalize_decoded()
  end

  @doc """
  Encodes a transaction for VeChain.

  This is a specialized encoder for VeChain transactions that handles the
  transaction structure properly.

  ## Transaction Structure

  A VeChain transaction consists of:
  - chain_tag (1 byte)
  - block_ref (8 bytes)
  - expiration (4 bytes)
  - clauses (list of clause structures)
  - gas_price_coef (1 byte)
  - gas (8 bytes)
  - depends_on (32 bytes or nil)
  - nonce (8 bytes)
  - reserved (list, for future use)
  - signature (65 bytes or nil)

  ## Parameters

    * `tx_map` - Map containing transaction fields

  ## Returns

  The RLP-encoded transaction binary.

  ## Examples

      iex> tx = %{
      ...>   chain_tag: 1,
      ...>   block_ref: <<0, 0, 0, 0, 0, 0, 0, 0>>,
      ...>   expiration: 32,
      ...>   clauses: [],
      ...>   gas_price_coef: 0,
      ...>   gas: 21000,
      ...>   depends_on: nil,
      ...>   nonce: 12345678,
      ...>   reserved: []
      ...> }
      iex> encoded = VeChain.RLP.encode_transaction(tx)
      iex> is_binary(encoded)
      true
  """
  @spec encode_transaction(map()) :: binary()
  def encode_transaction(tx) do
    # Build the base transaction structure
    tx_list = [
      tx.chain_tag,
      tx.block_ref,
      tx.expiration,
      encode_clauses(tx.clauses),
      tx.gas_price_coef,
      tx.gas,
      encode_optional(tx[:depends_on]),
      tx.nonce,
      tx[:reserved] || []
    ]

    # Add signature if present
    tx_list =
      if tx[:signature] do
        tx_list ++ [tx.signature]
      else
        tx_list
      end

    encode(tx_list)
  end

  @doc """
  Encodes a list of clauses for a transaction.

  Each clause contains:
  - to: address (20 bytes or empty for contract creation)
  - value: amount of VET (integer)
  - data: contract call data (binary)

  ## Parameters

    * `clauses` - List of clause maps

  ## Returns

  RLP-encodable list structure.

  ## Examples

      iex> clauses = [
      ...>   %{to: <<1::160>>, value: 0, data: ""},
      ...>   %{to: <<2::160>>, value: 1000, data: "0x1234"}
      ...> ]
      iex> encoded = VeChain.RLP.encode_clauses(clauses)
      iex> is_list(encoded)
      true
  """
  @spec encode_clauses(list(map())) :: list()
  def encode_clauses(clauses) when is_list(clauses) do
    Enum.map(clauses, fn clause ->
      [
        clause[:to] || "",
        clause[:value] || 0,
        clause[:data] || ""
      ]
    end)
  end

  @doc """
  Decodes a transaction from RLP-encoded binary.

  ## Parameters

    * `data` - RLP-encoded transaction binary

  ## Returns

  Map containing transaction fields.

  ## Examples

      iex> tx_map = %{chain_tag: 1, block_ref: <<0::64>>, expiration: 32, clauses: [], gas_price_coef: 0, gas: 21000, depends_on: nil, nonce: 12345678, reserved: []}
      iex> encoded = VeChain.RLP.encode_transaction(tx_map)
      iex> decoded = VeChain.RLP.decode_transaction(encoded)
      iex> is_map(decoded)
      true
  """
  @spec decode_transaction(binary()) :: map()
  def decode_transaction(data) when is_binary(data) do
    case decode(data) do
      [
        chain_tag,
        block_ref,
        expiration,
        clauses,
        gas_price_coef,
        gas,
        depends_on,
        nonce,
        reserved | rest
      ] ->
        tx = %{
          chain_tag: normalize_integer_field(chain_tag),
          block_ref: block_ref,
          expiration: normalize_integer_field(expiration),
          clauses: decode_clauses(clauses),
          gas_price_coef: normalize_integer_field(gas_price_coef),
          gas: normalize_integer_field(gas),
          depends_on: decode_optional(depends_on),
          nonce: normalize_integer_field(nonce),
          reserved: reserved
        }

        # Add signature if present
        case rest do
          [signature] -> Map.put(tx, :signature, signature)
          [] -> tx
        end

      _ ->
        raise ArgumentError, "Invalid transaction RLP structure"
    end
  end

  @doc """
  Decodes clauses from RLP structure.

  ## Parameters

    * `clauses` - RLP-decoded clause list

  ## Returns

  List of clause maps.
  """
  @spec decode_clauses(list()) :: list(map())
  def decode_clauses(clauses) when is_list(clauses) do
    Enum.map(clauses, fn
      [to, value, data] ->
        %{
          to: decode_optional(to),
          value: value,
          data: data
        }

      _ ->
        raise ArgumentError, "Invalid clause structure"
    end)
  end

  # Private helpers

  # Encode optional fields - empty string for nil, value otherwise
  defp encode_optional(nil), do: ""
  defp encode_optional(""), do: ""
  defp encode_optional(value), do: value

  # Decode optional fields - nil for empty string, value otherwise
  defp decode_optional(""), do: nil
  defp decode_optional(value), do: value

  # Normalize decoded values to match expected types
  # Single-byte binaries in range 0-127 should be returned as integers
  defp normalize_decoded(value) when is_binary(value) and byte_size(value) == 1 do
    <<byte>> = value
    if byte <= 127, do: byte, else: value
  end

  defp normalize_decoded(value) when is_list(value) do
    Enum.map(value, &normalize_decoded/1)
  end

  defp normalize_decoded(value), do: value

  # Normalize transaction-specific integer fields
  # Converts binaries to integers for numeric fields
  defp normalize_integer_field(""), do: 0
  defp normalize_integer_field(value) when is_integer(value), do: value

  defp normalize_integer_field(value) when is_binary(value) do
    :binary.decode_unsigned(value, :big)
  end
end
