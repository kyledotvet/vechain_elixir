defmodule VeChain.Utils do
  @moduledoc """
  Utility functions for VeChain SDK.

  Provides helper functions for:
  - Address validation and conversion
  - Hex encoding/decoding
  - Unit conversions (VET/VTHO)
  - Transaction nonce generation
  - Block reference creation

  ## Address Handling Strategy

  **Public API**: Hex strings with "0x" prefix
  **Internal**: 20-byte binaries for RLP/ABI operations

  Conversions happen at API boundaries using the functions in this module.
  """

  alias VeChain.Types

  @spec type_to_atom(Types.tx_type()) :: :dynamic_fee | :legacy
  def type_to_atom(0), do: :legacy
  def type_to_atom(81), do: :dynamic_fee

  # ========================================
  # Address Utilities
  # ========================================

  @doc """
  Encode to hex with 0x prefix.

  ## Examples

      iex> VeChain.Utils.hex_encode("VeChain_ex")
      "0x6574686572735f6578"
  """
  @spec hex_encode(binary() | nil, boolean()) :: String.t()
  def hex_encode(bin, include_prefix \\ true)
  def hex_encode(nil, _), do: nil
  def hex_encode(<<0>>, include_prefix), do: if(include_prefix, do: "0x0", else: "0")

  def hex_encode(bin, include_prefix),
    do: if(include_prefix, do: "0x", else: "") <> Base.encode16(bin, case: :lower)

  @doc """
  Decode from hex with (or without) 0x prefix.

  ## Examples

      iex> VeChain.Utils.hex_decode("0x6574686572735f6578")
      {:ok, "VeChain_ex"}

      iex> VeChain.Utils.hex_decode("6574686572735f6578")
      {:ok, "VeChain_ex"}

      iex> VeChain.Utils.hex_decode("0x686")
      {:ok, <<6, 134>>}
  """
  @spec hex_decode(String.t()) :: {:ok, binary} | :error
  def hex_decode(<<"0x", encoded::binary>>), do: hex_decode(encoded)
  def hex_decode(encoded) when rem(byte_size(encoded), 2) == 1, do: hex_decode("0" <> encoded)
  def hex_decode(encoded), do: Base.decode16(encoded, case: :mixed)

  @doc """
  Same as `hex_decode/1` but raises on error

  ## Examples

      iex> VeChain.Utils.hex_decode!("0x6574686572735f6578")
      "VeChain_ex"

      iex> VeChain.Utils.hex_decode!("6574686572735f6578")
      "VeChain_ex"
  """
  @spec hex_decode!(String.t()) :: binary() | no_return()
  def hex_decode!(encoded) do
    case hex_decode(encoded) do
      {:ok, decoded} -> decoded
      :error -> raise ArgumentError, "Invalid HEX input #{inspect(encoded)}"
    end
  end

  def maybe_hex_decode(nil), do: nil
  def maybe_hex_decode(hex), do: hex_decode!(hex)

  @doc """
  Converts an address to internal binary format.

  Accepts:
  - 20-byte binary (returns as-is)
  - Hex string with "0x" prefix (42 chars)
  - Hex string without prefix (40 chars)

  ## Parameters

    * `address` - Address in various formats

  ## Returns

    * `{:ok, binary}` - 20-byte address binary
    * `{:error, reason}` - Invalid address

  ## Examples

      iex> VeChain.Utils.to_binary("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      {:ok, <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>}

      iex> VeChain.Utils.to_binary(<<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>)
      {:ok, <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>}

      iex> VeChain.Utils.to_binary("invalid")
      {:error, "Invalid address format"}
  """
  @spec to_binary(binary()) :: {:ok, <<_::160>>} | {:error, String.t()}
  def to_binary(address) when is_binary(address) do
    case address do
      # Already binary (20 bytes)
      <<_::binary-size(20)>> ->
        {:ok, address}

      # Hex with 0x prefix (42 chars: 0x + 40 hex digits)
      "0x" <> hex when byte_size(hex) == 40 ->
        case Base.decode16(hex, case: :mixed) do
          {:ok, bin} -> {:ok, bin}
          :error -> {:error, "Invalid hex encoding"}
        end

      # Hex without prefix (40 chars)
      <<_::binary-size(40)>> ->
        case Base.decode16(address, case: :mixed) do
          {:ok, bin} -> {:ok, bin}
          :error -> {:error, "Invalid hex encoding"}
        end

      _ ->
        {:error, "Invalid address format"}
    end
  end

  @doc """
  Converts an address to hex string with "0x" prefix.

  ## Parameters

    * `address` - Address as 20-byte binary or hex string

  ## Returns

    * `{:ok, hex_string}` - Hex string with "0x" prefix
    * `{:error, reason}` - Invalid address

  ## Examples

      iex> binary = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
      iex> VeChain.Utils.to_hex(binary)
      {:ok, "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"}

      iex> VeChain.Utils.to_hex("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      {:ok, "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"}
  """
  @spec to_hex(binary()) :: {:ok, String.t()} | {:error, String.t()}
  def to_hex(address) do
    case to_binary(address) do
      {:ok, bin} ->
        hex = Base.encode16(bin, case: :lower)
        {:ok, "0x" <> hex}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Validates an address checksum (EIP-55 style with Blake2b).

  VeChain uses checksummed addresses similar to Ethereum's EIP-55, but with
  Blake2b instead of Keccak-256.

  ## Parameters

    * `address` - Address with checksum (hex string)

  ## Returns

  Boolean indicating if checksum is valid.

  ## Examples

      iex> VeChain.Utils.valid_checksum?("0x7567d83B7B8D80adDcb281a71D54Fc7B3364FfEd")
      true
  """
  @spec valid_checksum?(String.t()) :: boolean()
  def valid_checksum?("0x" <> hex_address) when byte_size(hex_address) == 40 do
    # Generate checksummed version and compare
    case to_checksum_address("0x" <> String.downcase(hex_address)) do
      checksummed -> "0x" <> hex_address == checksummed
      _ -> false
    end
  end

  def valid_checksum?(_), do: false

  @doc """
  Will convert an upper or lowercase Ethereum address to a checksum address.

  If `chain_id` is specified, ERC-1191 checksum encoding will be used.
  NOTE: ERC-1191 is generally NOT backwards compatible with ERC-55 encoding
        (encoding without `chain_id`).

  ## Examples

      iex> VeChain.Utils.to_checksum_address("0xc1912fee45d61c87cc5ea59dae31190fffff232d")
      "0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232d"

      iex> VeChain.Utils.to_checksum_address("0XC1912FEE45D61C87CC5EA59DAE31190FFFFF232D")
      "0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232d"

      iex> VeChain.Utils.to_checksum_address("0xde709f2102306220921060314715629080e2fb77", 31)
      "0xDE709F2102306220921060314715629080e2Fb77"

      iex> VeChain.Utils.to_checksum_address("0XDE709F2102306220921060314715629080e2Fb77", 30)
      "0xDe709F2102306220921060314715629080e2FB77"
  """
  @spec to_checksum_address(VeChain.Types.t_address() | <<_::320>>, pos_integer() | nil) ::
          VeChain.Types.t_address()
  def to_checksum_address(address, chain_id \\ nil)

  def to_checksum_address(<<"0x", address::binary-40>>, chain_id),
    do: to_checksum_address(address, chain_id)

  def to_checksum_address(<<"0X", address::binary-40>>, chain_id),
    do: to_checksum_address(address, chain_id)

  def to_checksum_address(<<address_bin::binary-20>>, chain_id),
    do: hex_encode(address_bin, false) |> to_checksum_address(chain_id)

  def to_checksum_address(address, nil), do: calculate_checksum_address(address, address)

  def to_checksum_address(address, chain_id) when is_integer(chain_id),
    do: calculate_checksum_address(address, "#{chain_id}0x#{address}")

  defp calculate_checksum_address(address, hash_input) do
    address = String.downcase(address)

    hashed_address =
      hash_input
      |> String.downcase()
      |> ExKeccak.hash_256()
      |> Base.encode16(case: :lower)

    checksum_address =
      address
      |> String.to_charlist()
      |> Enum.zip(String.to_charlist(hashed_address))
      |> Enum.map(fn
        {c, _} when c < ?a -> c
        {c, h} when h > ?7 -> :string.to_upper(c)
        {c, _} -> c
      end)
      |> to_string()

    "0x#{checksum_address}"
  end

  @doc """
  Checks if an address is valid.

  ## Parameters

    * `address` - Address to validate

  ## Returns

  Boolean indicating if address is valid.

  ## Examples

      iex> VeChain.Utils.valid_address?("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      true

      iex> VeChain.Utils.valid_address?("0xinvalid")
      false

      iex> VeChain.Utils.valid_address?(<<1, 2, 3>>)
      false
  """
  @spec valid_address?(binary()) :: boolean()
  def valid_address?(address) do
    case to_binary(address) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  # ========================================
  # Hex Encoding/Decoding
  # ========================================

  @doc """
  Encodes binary data to hex string with "0x" prefix.

  ## Parameters

    * `data` - Binary data to encode

  ## Returns

  Hex string with "0x" prefix.

  ## Examples

      iex> VeChain.Utils.encode_hex(<<1, 2, 3>>)
      "0x010203"

      iex> VeChain.Utils.encode_hex("hello")
      "0x68656c6c6f"
  """
  @spec encode_hex(binary()) :: String.t()
  def encode_hex(data) when is_binary(data) do
    "0x" <> Base.encode16(data, case: :lower)
  end

  @doc """
  Decodes hex string to binary.

  Handles strings with or without "0x" prefix.

  ## Parameters

    * `hex` - Hex string to decode

  ## Returns

    * `{:ok, binary}` - Decoded binary
    * `{:error, reason}` - Invalid hex string

  ## Examples

      iex> VeChain.Utils.decode_hex("0x010203")
      {:ok, <<1, 2, 3>>}

      iex> VeChain.Utils.decode_hex("010203")
      {:ok, <<1, 2, 3>>}

      iex> VeChain.Utils.decode_hex("0xZZZ")
      {:error, "Invalid hex encoding"}
  """
  @spec decode_hex(String.t()) :: {:ok, binary()} | {:error, String.t()}
  def decode_hex("0x" <> hex), do: decode_hex(hex)

  def decode_hex(hex) when is_binary(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bin} -> {:ok, bin}
      :error -> {:error, "Invalid hex encoding"}
    end
  end

  # ========================================
  # Unit Conversions
  # ========================================

  @doc """
  Converts VET to wei (smallest unit).

  1 VET = 10^18 wei

  ## Parameters

    * `vet` - Amount in VET (integer or float)

  ## Returns

  Amount in wei (integer).

  ## Examples

      iex> VeChain.Utils.vet_to_wei(1)
      1_000_000_000_000_000_000

      iex> VeChain.Utils.vet_to_wei(0.5)
      500_000_000_000_000_000

      iex> VeChain.Utils.vet_to_wei(10)
      10_000_000_000_000_000_000
  """
  @spec vet_to_wei(number()) :: non_neg_integer()
  def vet_to_wei(vet) when is_number(vet) do
    trunc(vet * 1_000_000_000_000_000_000)
  end

  @doc """
  Converts wei to VET.

  1 VET = 10^18 wei

  ## Parameters

    * `wei` - Amount in wei

  ## Returns

  Amount in VET (float).

  ## Examples

      iex> VeChain.Utils.wei_to_vet(1_000_000_000_000_000_000)
      1.0

      iex> VeChain.Utils.wei_to_vet(500_000_000_000_000_000)
      0.5
  """
  @spec wei_to_vet(non_neg_integer()) :: float()
  def wei_to_vet(wei) when is_integer(wei) do
    wei / 1_000_000_000_000_000_000
  end

  @doc """
  Converts VTHO to wei (smallest unit).

  1 VTHO = 10^18 wei (same as VET)

  ## Parameters

    * `vtho` - Amount in VTHO

  ## Returns

  Amount in wei (integer).

  ## Examples

      iex> VeChain.Utils.vtho_to_wei(100)
      100_000_000_000_000_000_000
  """
  @spec vtho_to_wei(number()) :: non_neg_integer()
  def vtho_to_wei(vtho), do: vet_to_wei(vtho)

  @doc """
  Converts wei to VTHO.

  1 VTHO = 10^18 wei (same as VET)

  ## Parameters

    * `wei` - Amount in wei

  ## Returns

  Amount in VTHO (float).

  ## Examples

      iex> VeChain.Utils.wei_to_vtho(100_000_000_000_000_000_000)
      100.0
  """
  @spec wei_to_vtho(non_neg_integer()) :: float()
  def wei_to_vtho(wei), do: wei_to_vet(wei)

  # ========================================
  # Transaction Utilities
  # ========================================

  @doc """
  Generates a transaction nonce.

  VeChain uses deterministic nonce generation based on timestamp and randomness.
  The nonce is an 8-byte (64-bit) value.

  ## Returns

  8-byte nonce value (integer).

  ## Examples

      iex> nonce = VeChain.Utils.generate_nonce()
      iex> is_integer(nonce) and nonce >= 0
      true
  """
  @spec generate_nonce() :: non_neg_integer()
  def generate_nonce do
    # Use current timestamp (milliseconds) + random bytes
    timestamp = System.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> :binary.decode_unsigned(:big)

    # Combine timestamp and random for uniqueness
    rem(timestamp * 1000 + random, 0xFFFFFFFFFFFFFFFF)
  end

  @doc """
  Creates a block reference from a block number and hash.

  A block reference is the first 8 bytes of a block hash. It's used in
  transactions to reference a recent block.

  ## Parameters

    * `block_number` - Block number (integer)
    * `block_id` - Block ID (32-byte hash or hex string)

  ## Returns

    * `{:ok, block_ref}` - 8-byte block reference
    * `{:error, reason}` - Invalid input

  ## Examples

      iex> block_id = "0x" <> String.duplicate("a", 64)
      iex> {:ok, ref} = VeChain.Utils.block_reference(12345, block_id)
      iex> byte_size(ref)
      8
  """
  @spec block_reference(non_neg_integer(), binary()) :: {:ok, <<_::64>>} | {:error, String.t()}
  def block_reference(block_number, block_id) when is_integer(block_number) do
    with {:ok, hash} <- decode_hex_hash(block_id) do
      # Take first 8 bytes of block hash
      <<ref::binary-size(8), _::binary>> = hash
      {:ok, ref}
    end
  end

  @doc """
  Parses a block reference to extract block number.

  The first 4 bytes of a block reference contain the block number.

  ## Parameters

    * `block_ref` - 8-byte block reference

  ## Returns

  Block number (integer).

  ## Examples

      iex> block_ref = <<0, 0, 48, 57, 1, 2, 3, 4>>
      iex> VeChain.Utils.parse_block_reference(block_ref)
      12345
  """
  @spec parse_block_reference(<<_::64>>) :: non_neg_integer()
  def parse_block_reference(<<block_number::32, _::binary>>) do
    block_number
  end

  # ========================================
  # Private Helpers
  # ========================================

  # Decode a 32-byte hash from hex string or binary
  defp decode_hex_hash(hash) when byte_size(hash) == 32, do: {:ok, hash}

  defp decode_hex_hash("0x" <> hex) when byte_size(hex) == 64 do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bin} -> {:ok, bin}
      :error -> {:error, "Invalid hex encoding"}
    end
  end

  defp decode_hex_hash(hex) when byte_size(hex) == 64 do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bin} -> {:ok, bin}
      :error -> {:error, "Invalid hex encoding"}
    end
  end

  defp decode_hex_hash(_), do: {:error, "Invalid hash format"}

  # ========================================
  # Convenience Macros/Aliases
  # ========================================

  @doc """
  Convenience function to convert VET amount.

  Same as `vet_to_wei/1` but with shorter name for use in code.

  ## Examples

      iex> VeChain.Utils.vet(10)
      10_000_000_000_000_000_000
  """
  @spec vet(number()) :: non_neg_integer()
  def vet(amount), do: vet_to_wei(amount)

  @doc """
  Convenience function to convert VTHO amount.

  Same as `vtho_to_wei/1` but with shorter name for use in code.

  ## Examples

      iex> VeChain.Utils.vtho(100)
      100_000_000_000_000_000_000
  """
  @spec vtho(number()) :: non_neg_integer()
  def vtho(amount), do: vtho_to_wei(amount)

  # ========================================
  # Aliases for Handoff Spec Compatibility
  # ========================================

  @doc """
  Alias for `to_binary/1`.

  Decodes address from hex string to binary.

  ## Examples

      iex> VeChain.Utils.decode_address("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      {:ok, <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>}
  """
  @spec decode_address(String.t()) :: {:ok, binary()} | {:error, String.t()}
  def decode_address(address), do: to_binary(address)

  @doc """
  Alias for `to_binary/1` that raises on error.

  Decodes address from hex string to binary. Raises on invalid address.

  ## Examples

      iex> VeChain.Utils.decode_address!("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
  """
  @spec decode_address!(String.t()) :: binary()
  def decode_address!(address) do
    case to_binary(address) do
      {:ok, binary} -> binary
      {:error, reason} -> raise ArgumentError, "Invalid address: #{reason}"
    end
  end

  @doc """
  Alias for `to_hex/1`.

  Encodes address from binary to hex string.

  ## Examples

      iex> binary = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
      iex> VeChain.Utils.encode_address(binary)
      {:ok, "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"}
  """
  @spec encode_address(binary()) :: {:ok, String.t()} | {:error, String.t()}
  def encode_address(address_binary), do: to_hex(address_binary)

  @doc """
  Alias for `to_hex/1` that raises on error.

  Encodes address from binary to hex string. Raises on invalid address.

  ## Examples

      iex> binary = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
      iex> VeChain.Utils.encode_address!(binary)
      "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
  """
  @spec encode_address!(binary()) :: String.t()
  def encode_address!(address_binary) do
    case to_hex(address_binary) do
      {:ok, hex} -> hex
      {:error, reason} -> raise ArgumentError, "Invalid address: #{reason}"
    end
  end

  @doc """
  Normalize address to internal binary format.

  Accepts various formats and converts to 20-byte binary.
  This is a convenience function that unwraps the result tuple.

  ## Examples

      iex> VeChain.Utils.normalize_address("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>

      iex> binary = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
      iex> VeChain.Utils.normalize_address(binary)
      <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
  """
  @spec normalize_address(String.t() | binary()) :: binary()
  def normalize_address(address) do
    case to_binary(address) do
      {:ok, binary} -> binary
      {:error, reason} -> raise ArgumentError, "Invalid address: #{reason}"
    end
  end

  # ========================================
  # Transaction Display Formatting
  # ========================================

  @doc """
  Formats a transaction ID as a lowercase hex string with "0x" prefix.

  ## Parameters

    * `tx_id` - Transaction ID as 32-byte binary

  ## Returns

  Lowercase hex string with "0x" prefix.

  ## Examples

      iex> tx_id = <<139, 134, 134, 238, 84, 94, 124, 236, 9, 145, 214, 108, 125, 152, 131, 241, 222, 122, 37, 89, 29, 182, 167, 180, 117, 132, 130, 136, 78, 61, 64, 133>>
      iex> VeChain.Utils.format_transaction_id(tx_id)
      "0x8b8686ee545e7cec0991d66c7d9883f1de7a25591db6a7b4758482884e3d4085"
  """
  @spec format_transaction_id(binary()) :: String.t()
  def format_transaction_id(<<_::binary-size(32)>> = tx_id) do
    encode_hex(tx_id)
  end

  @doc """
  Formats a nonce as a lowercase hex string with "0x" prefix.

  Accepts both integer and binary nonce values.

  ## Parameters

    * `nonce` - Nonce as integer or binary

  ## Returns

  Lowercase hex string with "0x" prefix.

  ## Examples

      iex> VeChain.Utils.format_nonce(113829055475)
      "0x1a80bd8bf3"

      iex> VeChain.Utils.format_nonce(<<26, 128, 189, 139, 243>>)
      "0x1a80bd8bf3"
  """
  @spec format_nonce(non_neg_integer() | binary()) :: String.t()
  def format_nonce(nonce) when is_integer(nonce) do
    # Convert integer to binary with variable length (minimum needed bytes)
    binary = :binary.encode_unsigned(nonce, :big)
    encode_hex(binary)
  end

  def format_nonce(nonce) when is_binary(nonce) do
    encode_hex(nonce)
  end

  @doc """
  Formats a chain tag as a lowercase hex string with "0x" prefix.

  ## Parameters

    * `chain_tag` - Chain tag as integer (0-255)

  ## Returns

  Lowercase hex string with "0x" prefix.

  ## Examples

      iex> VeChain.Utils.format_chain_tag(0x4a)
      "0x4a"

      iex> VeChain.Utils.format_chain_tag(39)
      "0x27"
  """
  @spec format_chain_tag(byte()) :: String.t()
  def format_chain_tag(chain_tag)
      when is_integer(chain_tag) and chain_tag >= 0 and chain_tag <= 255 do
    encode_hex(<<chain_tag>>)
  end
end
