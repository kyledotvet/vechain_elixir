defmodule VeChain.Crypto.Secp256k1 do
  @moduledoc """
  Secp256k1 elliptic curve cryptography for VeChain.

  VeChain uses the same secp256k1 curve as Bitcoin and Ethereum for public key
  cryptography and ECDSA signatures. However, it differs in the **hashing**:

  - **Signing**: Sign Blake2b-256 hash (not Keccak-256)
  - **Curve**: secp256k1 (same as Ethereum/Bitcoin)
  - **Signature**: 65-byte recoverable signature (r, s, v)

  ## Key Generation

      # Generate a new private key
      private_key = VeChain.Crypto.Secp256k1.generate_private_key()

      # Derive public key
      public_key = VeChain.Crypto.Secp256k1.private_key_to_public_key(private_key)

      # Derive address
      address = VeChain.Crypto.Blake2b.public_key_to_address(public_key)

  ## Transaction Signing

      # Create signing hash (Blake2b of unsigned tx)
      signing_hash = VeChain.Crypto.Blake2b.signing_hash(unsigned_tx_rlp)

      # Sign with private key
      signature = VeChain.Crypto.Secp256k1.sign(signing_hash, private_key)

      # Verify signature
      {:ok, recovered_pubkey} = VeChain.Crypto.Secp256k1.recover(signing_hash, signature)

  ## Signature Format

  VeChain signatures are 65 bytes:
  - r: 32 bytes (signature component)
  - s: 32 bytes (signature component)
  - v: 1 byte (recovery id, typically 0 or 1)

  The recovery id allows recovering the public key from the signature.
  """

  alias VeChain.Crypto.Blake2b

  @doc """
  Generates a new random private key.

  The private key is a 32-byte random number that must be kept secret.

  ## Returns

  32-byte private key binary.

  ## Examples

      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> byte_size(private_key)
      32

      iex> # Private keys should be unique
      iex> key1 = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> key2 = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> key1 != key2
      true
  """
  @spec generate_private_key() :: <<_::256>>
  def generate_private_key do
    :crypto.strong_rand_bytes(32)
  end

  @doc """
  Derives the public key from a private key.

  Returns the uncompressed public key (64 bytes, without the 0x04 prefix).

  ## Parameters

    * `private_key` - 32-byte private key

  ## Returns

  64-byte uncompressed public key (x and y coordinates, 32 bytes each).

  ## Examples

      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> public_key = VeChain.Crypto.Secp256k1.private_key_to_public_key(private_key)
      iex> byte_size(public_key)
      64
  """
  @spec private_key_to_public_key(<<_::256>>) :: <<_::512>>
  def private_key_to_public_key(<<private_key::binary-size(32)>>) do
    {:ok, public_key} = ExSecp256k1.create_public_key(private_key)

    # Remove the 0x04 prefix from uncompressed public key
    case public_key do
      <<0x04, rest::binary-size(64)>> -> rest
      <<rest::binary-size(64)>> -> rest
    end
  end

  @doc """
  Derives a VeChain address from a private key.

  This is a convenience function that combines public key derivation and
  address generation.

  ## Parameters

    * `private_key` - 32-byte private key

  ## Returns

  20-byte address binary.

  ## Examples

      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> address = VeChain.Crypto.Secp256k1.private_key_to_address(private_key)
      iex> byte_size(address)
      20
  """
  @spec private_key_to_address(<<_::256>>) :: <<_::160>>
  def private_key_to_address(<<private_key::binary-size(32)>>) do
    private_key
    |> private_key_to_public_key()
    |> Blake2b.public_key_to_address()
  end

  @doc """
  Signs a message hash with a private key.

  Returns a 65-byte recoverable signature (r, s, recovery_id).

  **IMPORTANT**: The message should already be hashed with Blake2b-256.
  This function signs the hash, not the raw message.

  ## Parameters

    * `message_hash` - 32-byte Blake2b hash of the message
    * `private_key` - 32-byte private key

  ## Returns

  65-byte signature binary (r: 32 bytes, s: 32 bytes, v: 1 byte).

  ## Examples

      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> message_hash = VeChain.Crypto.Blake2b.hash("hello")
      iex> signature = VeChain.Crypto.Secp256k1.sign(message_hash, private_key)
      iex> byte_size(signature)
      65
  """
  @spec sign(<<_::256>>, <<_::256>>) :: <<_::520>>
  def sign(<<message_hash::binary-size(32)>>, <<private_key::binary-size(32)>>) do
    {:ok, {r, s, recovery_id}} = ExSecp256k1.sign(message_hash, private_key)

    # Return as 65-byte binary: r (32) + s (32) + v (1)
    <<r::binary-size(32), s::binary-size(32), recovery_id::8>>
  end

  @doc """
  Signs a message hash with a private key and returns compact format.

  This is the same as `sign/2` but returns a map with separated components
  for easier inspection and debugging.

  ## Parameters

    * `message_hash` - 32-byte Blake2b hash of the message
    * `private_key` - 32-byte private key

  ## Returns

  Map with `:r`, `:s`, and `:v` fields.

  ## Examples

      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> message_hash = VeChain.Crypto.Blake2b.hash("hello")
      iex> compact = VeChain.Crypto.Secp256k1.sign_compact(message_hash, private_key)
      iex> is_map(compact) and Map.has_key?(compact, :r) and Map.has_key?(compact, :s) and Map.has_key?(compact, :v)
      true
  """
  @spec sign_compact(<<_::256>>, <<_::256>>) :: %{r: <<_::256>>, s: <<_::256>>, v: 0..3}
  def sign_compact(message_hash, private_key) do
    <<r::binary-size(32), s::binary-size(32), v::8>> = sign(message_hash, private_key)
    %{r: r, s: s, v: v}
  end

  @doc """
  Recovers the public key from a signature and message hash.

  This is useful for verification and for recovering the signer's address
  without needing to know their public key in advance.

  ## Parameters

    * `message_hash` - 32-byte Blake2b hash of the message
    * `signature` - 65-byte signature (r, s, recovery_id)

  ## Returns

    * `{:ok, public_key}` - 64-byte uncompressed public key
    * `{:error, reason}` - If recovery fails

  ## Examples

      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> message_hash = VeChain.Crypto.Blake2b.hash("hello")
      iex> signature = VeChain.Crypto.Secp256k1.sign(message_hash, private_key)
      iex> {:ok, public_key} = VeChain.Crypto.Secp256k1.recover(message_hash, signature)
      iex> byte_size(public_key)
      64

      iex> # Verify it matches original public key
      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> original_pubkey = VeChain.Crypto.Secp256k1.private_key_to_public_key(private_key)
      iex> message_hash = VeChain.Crypto.Blake2b.hash("hello")
      iex> signature = VeChain.Crypto.Secp256k1.sign(message_hash, private_key)
      iex> {:ok, recovered_pubkey} = VeChain.Crypto.Secp256k1.recover(message_hash, signature)
      iex> recovered_pubkey == original_pubkey
      true
  """
  @spec recover(<<_::256>>, <<_::520>>) :: {:ok, <<_::512>>} | {:error, term()}
  def recover(<<message_hash::binary-size(32)>>, <<r::binary-size(32), s::binary-size(32), recovery_id::8>>) do
    case ExSecp256k1.recover(message_hash, r, s, recovery_id) do
      {:ok, <<0x04, public_key::binary-size(64)>>} ->
        {:ok, public_key}

      {:ok, public_key} when byte_size(public_key) == 64 ->
        {:ok, public_key}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Recovers the address from a signature and message hash.

  This is a convenience function that combines public key recovery and
  address derivation.

  ## Parameters

    * `message_hash` - 32-byte Blake2b hash of the message
    * `signature` - 65-byte signature

  ## Returns

    * `{:ok, address}` - 20-byte address
    * `{:error, reason}` - If recovery fails

  ## Examples

      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> message_hash = VeChain.Crypto.Blake2b.hash("hello")
      iex> signature = VeChain.Crypto.Secp256k1.sign(message_hash, private_key)
      iex> {:ok, address} = VeChain.Crypto.Secp256k1.recover_address(message_hash, signature)
      iex> byte_size(address)
      20

      iex> # Verify it matches original address
      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> original_address = VeChain.Crypto.Secp256k1.private_key_to_address(private_key)
      iex> message_hash = VeChain.Crypto.Blake2b.hash("hello")
      iex> signature = VeChain.Crypto.Secp256k1.sign(message_hash, private_key)
      iex> {:ok, recovered_address} = VeChain.Crypto.Secp256k1.recover_address(message_hash, signature)
      iex> recovered_address == original_address
      true
  """
  @spec recover_address(<<_::256>>, <<_::520>>) :: {:ok, <<_::160>>} | {:error, term()}
  def recover_address(message_hash, signature) do
    case recover(message_hash, signature) do
      {:ok, public_key} ->
        {:ok, Blake2b.public_key_to_address(public_key)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Verifies a signature against a message hash and public key.

  ## Parameters

    * `message_hash` - 32-byte Blake2b hash of the message
    * `signature` - 65-byte signature
    * `public_key` - 64-byte uncompressed public key

  ## Returns

  Boolean indicating if the signature is valid.

  ## Examples

      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> message_hash = VeChain.Crypto.Blake2b.hash("hello")
      iex> signature = VeChain.Crypto.Secp256k1.sign(message_hash, private_key)
      iex> public_key = VeChain.Crypto.Secp256k1.private_key_to_public_key(private_key)
      iex> VeChain.Crypto.Secp256k1.verify(message_hash, signature, public_key)
      true

      iex> # Wrong public key
      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> message_hash = VeChain.Crypto.Blake2b.hash("hello")
      iex> signature = VeChain.Crypto.Secp256k1.sign(message_hash, private_key)
      iex> other_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> other_pubkey = VeChain.Crypto.Secp256k1.private_key_to_public_key(other_key)
      iex> VeChain.Crypto.Secp256k1.verify(message_hash, signature, other_pubkey)
      false
  """
  @spec verify(<<_::256>>, <<_::520>>, <<_::512>>) :: boolean()
  def verify(message_hash, signature, public_key) do
    case recover(message_hash, signature) do
      {:ok, recovered_pubkey} -> recovered_pubkey == public_key
      {:error, _} -> false
    end
  end

  @doc """
  Verifies a signature against a message hash and address.

  This is useful when you have an address but not the public key.

  ## Parameters

    * `message_hash` - 32-byte Blake2b hash of the message
    * `signature` - 65-byte signature
    * `address` - 20-byte address

  ## Returns

  Boolean indicating if the signature is valid for the address.

  ## Examples

      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> message_hash = VeChain.Crypto.Blake2b.hash("hello")
      iex> signature = VeChain.Crypto.Secp256k1.sign(message_hash, private_key)
      iex> address = VeChain.Crypto.Secp256k1.private_key_to_address(private_key)
      iex> VeChain.Crypto.Secp256k1.verify_address(message_hash, signature, address)
      true
  """
  @spec verify_address(<<_::256>>, <<_::520>>, <<_::160>>) :: boolean()
  def verify_address(message_hash, signature, address) do
    case recover_address(message_hash, signature) do
      {:ok, recovered_address} -> recovered_address == address
      {:error, _} -> false
    end
  end

  @doc """
  Validates that a private key is valid for secp256k1.

  A valid private key must be:
  - 32 bytes long
  - Greater than 0
  - Less than the secp256k1 curve order

  ## Parameters

    * `private_key` - 32-byte private key candidate

  ## Returns

  Boolean indicating if the private key is valid.

  ## Examples

      iex> valid_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> VeChain.Crypto.Secp256k1.valid_private_key?(valid_key)
      true

      iex> invalid_key = <<0::256>>
      iex> VeChain.Crypto.Secp256k1.valid_private_key?(invalid_key)
      false
  """
  @spec valid_private_key?(binary()) :: boolean()
  def valid_private_key?(<<private_key::binary-size(32)>>) do
    # Convert to integer
    key_int = :binary.decode_unsigned(private_key, :big)

    # secp256k1 curve order (n)
    n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

    # Private key must be in range [1, n-1]
    key_int > 0 and key_int < n
  end

  def valid_private_key?(_), do: false

  @doc """
  Normalizes a signature to low-s form.

  Some systems require signatures to have s-values in the lower half of the
  curve order to prevent signature malleability. This function ensures that.

  ## Parameters

    * `signature` - 65-byte signature

  ## Returns

  65-byte signature with normalized s-value.

  ## Examples

      iex> private_key = VeChain.Crypto.Secp256k1.generate_private_key()
      iex> message_hash = VeChain.Crypto.Blake2b.hash("hello")
      iex> signature = VeChain.Crypto.Secp256k1.sign(message_hash, private_key)
      iex> normalized = VeChain.Crypto.Secp256k1.normalize_signature(signature)
      iex> byte_size(normalized)
      65
  """
  @spec normalize_signature(<<_::520>>) :: <<_::520>>
  def normalize_signature(<<r::binary-size(32), s::binary-size(32), v::8>>) do
    # secp256k1 curve order
    n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
    half_n = div(n, 2)

    s_int = :binary.decode_unsigned(s, :big)

    if s_int > half_n do
      # Flip s to n - s and adjust recovery id
      new_s = :binary.encode_unsigned(n - s_int, :big) |> pad_to_32_bytes()
      new_v = if v == 0, do: 1, else: 0
      <<r::binary, new_s::binary, new_v::8>>
    else
      <<r::binary, s::binary, v::8>>
    end
  end

  # Private helper to pad binary to 32 bytes
  defp pad_to_32_bytes(bin) when byte_size(bin) < 32 do
    padding = :binary.copy(<<0>>, 32 - byte_size(bin))
    padding <> bin
  end

  defp pad_to_32_bytes(bin), do: bin
end
