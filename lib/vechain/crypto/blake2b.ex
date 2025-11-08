defmodule VeChain.Crypto.Blake2b do
  @moduledoc """
  Blake2b-256 hashing for VeChain.

  **IMPORTANT**: VeChain uses Blake2b-256 for specific operations, but NOT for
  address derivation (which uses Keccak-256 like Ethereum).

  Blake2b is used for:
  - Transaction ID generation
  - Transaction signing hash generation

  Blake2b is a cryptographic hash function faster than MD5, SHA-1, SHA-2, and
  SHA-3, yet is at least as secure as the latest standard SHA-3.

  ## Examples

      # Hash a message
      iex> VeChain.Crypto.Blake2b.hash("hello")
      <<50, 77, 207, 2, 125, 212, 163, 10, 147, 44, 68, 31, 54, 90, 37, 232,
        107, 23, 61, 239, 164, 184, 229, 137, 72, 37, 52, 113, 184, 27, 114, 207>>

      # Hash transaction for signing
      iex> tx_rlp = <<1, 2, 3, 4, 5>>  # Example RLP-encoded transaction
      iex> signing_hash = VeChain.Crypto.Blake2b.hash(tx_rlp)
      iex> byte_size(signing_hash)
      32

  ## Technical Details

  VeChain uses Blake2b with:
  - Output length: 256 bits (32 bytes)
  - No salt
  - No personalization
  - Standard Blake2b parameters

  ## Key Use Cases

  1. **Transaction ID**: Blake2b(RLP(signed_transaction))
  2. **Signing Hash**: Blake2b(RLP(unsigned_transaction))

  ## NOTE: Address Derivation

  Address derivation uses **Keccak-256**, not Blake2b. See `VeChain.Crypto.Address`
  for address-related operations.
  """

  @doc """
  Computes the Blake2b-256 hash of the input data.

  ## Parameters

    * `data` - Binary data to hash

  ## Returns

  32-byte binary hash.

  ## Examples

      iex> VeChain.Crypto.Blake2b.hash("hello")
      <<50, 77, 207, 2, 125, 212, 163, 10, 147, 44, 68, 31, 54, 90, 37, 232,
        107, 23, 61, 239, 164, 184, 229, 137, 72, 37, 52, 113, 184, 27, 114, 207>>

      iex> hash = VeChain.Crypto.Blake2b.hash("test")
      iex> byte_size(hash)
      32
  """
  @spec hash(binary()) :: <<_::256>>
  def hash(data) when is_binary(data) do
    # Blake2b with 32-byte (256-bit) output
    Blake2.hash2b(data, 32)
  end

  @doc """
  Computes the transaction ID from a signed transaction.

  The transaction ID is the Blake2b-256 hash of the RLP-encoded signed transaction.
  This is returned by the Thor API and used to query transaction status.

  ## Parameters

    * `signed_tx_rlp` - RLP-encoded signed transaction binary

  ## Returns

  32-byte transaction ID as binary.

  ## Examples

      iex> signed_tx_rlp = <<1, 2, 3, 4, 5>>  # Example RLP-encoded signed transaction
      iex> tx_id = VeChain.Crypto.Blake2b.transaction_id(signed_tx_rlp)
      iex> byte_size(tx_id)
      32
      iex> tx_id_hex = "0x" <> Base.encode16(tx_id, case: :lower)
      iex> String.starts_with?(tx_id_hex, "0x")
      true
  """
  @spec transaction_id(binary()) :: <<_::256>>
  def transaction_id(signed_tx_rlp) when is_binary(signed_tx_rlp) do
    hash(signed_tx_rlp)
  end

  @doc """
  **DEPRECATED**: This function is incorrect and should not be used.

  VeChain uses Keccak-256 for address derivation, NOT Blake2b.
  Use `VeChain.Crypto.Address.from_public_key/1` instead.

  This function is kept for backwards compatibility but will be removed in a future version.

  ## Parameters

    * `public_key` - 64-byte uncompressed public key (without 0x04 prefix)

  ## Returns

  20-byte address binary (INCORRECT - uses Blake2b instead of Keccak-256).
  """
  @deprecated "Use VeChain.Crypto.Address.from_public_key/1 instead. VeChain uses Keccak-256 for addresses, not Blake2b."
  @spec public_key_to_address(<<_::512>>) :: <<_::160>>
  def public_key_to_address(<<public_key::binary-size(64)>>) do
    # NOTE: This is INCORRECT for VeChain address derivation
    # VeChain uses Keccak-256, not Blake2b
    # This function is deprecated and kept only for backwards compatibility
    hash(public_key)
    |> binary_part(12, 20)
  end

  @doc """
  Computes the signing hash for a transaction.

  This is the hash that needs to be signed with the private key using secp256k1.
  It's the Blake2b-256 hash of the RLP-encoded unsigned transaction.

  ## Parameters

    * `unsigned_tx_rlp` - RLP-encoded unsigned transaction binary

  ## Returns

  32-byte signing hash.

  ## Examples

      iex> # Example unsigned transaction RLP
      iex> unsigned_rlp = <<1, 2, 3, 4, 5>>
      iex> signing_hash = VeChain.Crypto.Blake2b.signing_hash(unsigned_rlp)
      iex> byte_size(signing_hash)
      32
  """
  @spec signing_hash(binary()) :: <<_::256>>
  def signing_hash(unsigned_tx_rlp) when is_binary(unsigned_tx_rlp) do
    hash(unsigned_tx_rlp)
  end

  @doc """
  Hashes data and returns it as a hex string with 0x prefix.

  Convenience function for when you need the hash as a hex string.

  ## Parameters

    * `data` - Binary data to hash

  ## Returns

  Hex string with "0x" prefix.

  ## Examples

      iex> VeChain.Crypto.Blake2b.hash_hex("hello")
      "0x324dcf027dd4a30a932c441f365a25e86b173defa4b8e58948253471b81b72cf"
  """
  @spec hash_hex(binary()) :: String.t()
  def hash_hex(data) when is_binary(data) do
    hash(data)
    |> Base.encode16(case: :lower)
    |> then(&("0x" <> &1))
  end

  @doc """
  Verifies that a hash matches the expected value.

  Useful for testing and validation.

  ## Parameters

    * `data` - Binary data to hash
    * `expected_hash` - Expected hash (binary or hex string)

  ## Returns

  Boolean indicating if the hash matches.

  ## Examples

      iex> expected_hash = VeChain.Crypto.Blake2b.hash("hello")
      iex> VeChain.Crypto.Blake2b.verify_hash("hello", expected_hash)
      true

      iex> VeChain.Crypto.Blake2b.verify_hash("hello", "0x324dcf027dd4a30a932c441f365a25e86b173defa4b8e58948253471b81b72cf")
      true
  """
  @spec verify_hash(binary(), binary() | String.t()) :: boolean()
  def verify_hash(data, expected_hash) when is_binary(data) do
    computed = hash(data)

    expected =
      case expected_hash do
        "0x" <> hex -> Base.decode16!(hex, case: :mixed)
        <<_::binary-size(32)>> -> expected_hash
        _ -> raise ArgumentError, "Expected hash must be 32-byte binary or hex string"
      end

    computed == expected
  end

  @doc """
  Computes multiple hashes in sequence (double hash, triple hash, etc).

  Sometimes you need to hash data multiple times. This function makes it convenient.

  ## Parameters

    * `data` - Binary data to hash
    * `iterations` - Number of times to hash (must be >= 1)

  ## Returns

  The final hash after n iterations.

  ## Examples

      iex> # Double hash
      iex> double = VeChain.Crypto.Blake2b.hash_n("hello", 2)
      iex> double == VeChain.Crypto.Blake2b.hash(VeChain.Crypto.Blake2b.hash("hello"))
      true

      iex> # Triple hash
      iex> triple = VeChain.Crypto.Blake2b.hash_n("hello", 3)
      iex> byte_size(triple)
      32
  """
  @spec hash_n(binary(), pos_integer()) :: <<_::256>>
  def hash_n(data, iterations) when is_binary(data) and iterations >= 1 do
    Enum.reduce(1..iterations, data, fn _, acc -> hash(acc) end)
  end
end
