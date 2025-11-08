defmodule VeChain.Crypto.Address do
  @moduledoc """
  Address derivation and validation for VeChain.

  This module provides functions for deriving VeChain addresses from
  public keys, private keys, and signatures. It also includes validation
  and checksum functions.

  ## Address Derivation

  VeChain addresses are derived from public keys using Keccak-256 hashing:
  1. Hash the 64-byte uncompressed public key with Keccak-256
  2. Take the last 20 bytes of the hash
  3. Optionally apply EIP-55 checksumming with Keccak-256

  **IMPORTANT**: VeChain uses Keccak-256 for address derivation (same as Ethereum).
  Blake2b is used for transaction IDs and signing hashes, but NOT for addresses.

  ## Examples

      # From private key
      private_key = Secp256k1.generate_private_key()
      address = Address.from_private_key(private_key)

      # From public key
      public_key = Secp256k1.private_key_to_public_key(private_key)
      address = Address.from_public_key(public_key)

      # From signature (recover signer)
      message_hash = :crypto.hash(:sha256, "hello")
      signature = Secp256k1.sign(message_hash, private_key)
      {:ok, address} = Address.from_signature(message_hash, signature)

      # Validate address
      Address.valid?("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")  # => true

      # Checksum address
      {:ok, checksummed} = Address.checksum("0x7567d83b...")
  """

  alias VeChain.Crypto.Secp256k1
  alias VeChain.Utils

  @doc """
  Derives an address from a public key.

  VeChain uses Keccak-256 for address derivation (same as Ethereum):
  1. Hash the 64-byte uncompressed public key with Keccak-256
  2. Take the last 20 bytes of the hash

  ## Parameters

    * `public_key` - 64-byte uncompressed public key (without 0x04 prefix)

  ## Returns

  20-byte address binary.

  ## Examples

      iex> alias VeChain.Crypto.{Address, Secp256k1}
      iex> private_key = Secp256k1.generate_private_key()
      iex> public_key = Secp256k1.private_key_to_public_key(private_key)
      iex> address = Address.from_public_key(public_key)
      iex> byte_size(address)
      20
  """
  @spec from_public_key(binary()) :: binary()
  def from_public_key(<<public_key::binary-size(64)>>) do
    # VeChain uses Keccak-256 for address derivation (same as Ethereum)
    public_key
    |> ExKeccak.hash_256()
    |> binary_part(12, 20)
  end

  @doc """
  Derives an address from a private key.

  This is a convenience function that combines public key derivation
  and address generation.

  ## Parameters

    * `private_key` - 32-byte private key

  ## Returns

  20-byte address binary.

  ## Examples

      iex> private_key = Secp256k1.generate_private_key()
      iex> address = Address.from_private_key(private_key)
      iex> byte_size(address)
      20
  """
  @spec from_private_key(binary()) :: binary()
  def from_private_key(<<private_key::binary-size(32)>>) do
    Secp256k1.private_key_to_address(private_key)
  end

  @doc """
  Recovers the signer's address from a signature.

  ## Parameters

    * `message_hash` - 32-byte hash of the message (typically Blake2b for VeChain transactions)
    * `signature` - 65-byte signature

  ## Returns

    * `{:ok, address}` - 20-byte address
    * `{:error, reason}` - If recovery fails

  ## Examples

      iex> alias VeChain.Crypto.{Address, Secp256k1}
      iex> private_key = Secp256k1.generate_private_key()
      iex> message_hash = :crypto.hash(:sha256, "hello")
      iex> signature = Secp256k1.sign(message_hash, private_key)
      iex> {:ok, address} = Address.from_signature(message_hash, signature)
      iex> byte_size(address)
      20
  """
  @spec from_signature(binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def from_signature(<<message_hash::binary-size(32)>>, <<signature::binary-size(65)>>) do
    Secp256k1.recover_address(message_hash, signature)
  end

  @doc """
  Validates an address format.

  Checks if the address is properly formatted (20 bytes or 42-char hex string).

  ## Parameters

    * `address` - Address to validate (binary or hex string)

  ## Returns

  Boolean indicating if the address format is valid.

  ## Examples

      iex> Address.valid?("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      true

      iex> Address.valid?("0xinvalid")
      false

      iex> Address.valid?(<<1, 2, 3>>)
      false
  """
  @spec valid?(binary()) :: boolean()
  def valid?(address) when is_binary(address) do
    Utils.valid_address?(address)
  end

  @doc """
  Validates an address checksum.

  Checks if the address has a valid EIP-55 style checksum (using Keccak-256).

  ## Parameters

    * `address` - Checksummed address (hex string with 0x prefix)

  ## Returns

  Boolean indicating if the checksum is valid.

  ## Examples

      iex> Address.valid_checksum?("0x7567D83b7b8d80ADdCb281A71d54Fc7B3364ffed")
      true

      iex> Address.valid_checksum?("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      false  # All lowercase, no checksum
  """
  @spec valid_checksum?(String.t()) :: boolean()
  def valid_checksum?(address) when is_binary(address) do
    Utils.valid_checksum?(address)
  end

  @doc """
  Generates a checksummed address (EIP-55 style with Keccak-256).

  ## Parameters

    * `address` - Address as binary or hex string

  ## Returns

    * `{:ok, checksummed_address}` - Checksummed hex string
    * `{:error, reason}` - Invalid address

  ## Examples

      iex> {:ok, checksummed} = Address.checksum("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      iex> checksummed
      "0x7567D83b7b8d80ADdCb281A71d54Fc7B3364ffed"

      iex> binary = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
      iex> {:ok, checksummed} = Address.checksum(binary)
      iex> checksummed
      "0x7567D83b7b8d80ADdCb281A71d54Fc7B3364ffed"
  """
  @spec checksum(binary()) :: {:ok, String.t()} | {:error, String.t()}
  def checksum(address) when is_binary(address) do
    case Utils.address_to_binary(address) do
      {:ok, bin} -> {:ok, Utils.to_checksum_address("0x" <> Base.encode16(bin, case: :lower))}
      {:error, _} = error -> error
    end
  end

  @doc """
  Converts an address to binary format.

  Accepts hex strings (with or without 0x prefix) or binary addresses.

  ## Parameters

    * `address` - Address in various formats

  ## Returns

    * `{:ok, binary}` - 20-byte address binary
    * `{:error, reason}` - Invalid address

  ## Examples

      iex> {:ok, binary} = Address.to_binary("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      iex> byte_size(binary)
      20

      iex> binary = <<1::160>>
      iex> {:ok, result} = Address.to_binary(binary)
      iex> result == binary
      true
  """
  @spec to_binary(binary()) :: {:ok, binary()} | {:error, String.t()}
  def to_binary(address) when is_binary(address) do
    Utils.address_to_binary(address)
  end

  @doc """
  Converts an address to hex string with 0x prefix.

  ## Parameters

    * `address` - Address as binary or hex string

  ## Returns

    * `{:ok, hex_string}` - Hex string with 0x prefix
    * `{:error, reason}` - Invalid address

  ## Examples

      iex> binary = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
      iex> {:ok, hex} = Address.to_hex(binary)
      iex> hex
      "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
  """
  @spec to_hex(binary()) :: {:ok, String.t()} | {:error, String.t()}
  def to_hex(address) when is_binary(address) do
    Utils.to_hex(address)
  end

  @doc """
  Checks if two addresses are equal.

  Handles comparison of addresses in different formats (binary, hex, checksummed).

  ## Parameters

    * `address1` - First address
    * `address2` - Second address

  ## Returns

  Boolean indicating if addresses are equal.

  ## Examples

      iex> alias VeChain.Crypto.Address
      iex> a1 = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      iex> a2 = "0x7567d83B7B8D80adDcb281a71D54Fc7B3364FfEd"  # checksummed
      iex> Address.equal?(a1, a2)
      true

      iex> alias VeChain.Crypto.Address
      iex> a1 = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      iex> binary = <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
      iex> Address.equal?(a1, binary)
      true
  """
  @spec equal?(binary(), binary()) :: boolean()
  def equal?(address1, address2) do
    with {:ok, bin1} <- to_binary(address1),
         {:ok, bin2} <- to_binary(address2) do
      bin1 == bin2
    else
      _ -> false
    end
  end

  @doc """
  Checks if an address is the zero address.

  The zero address is 0x0000000000000000000000000000000000000000.

  ## Parameters

    * `address` - Address to check

  ## Returns

  Boolean indicating if the address is the zero address.

  ## Examples

      iex> Address.zero?("0x0000000000000000000000000000000000000000")
      true

      iex> Address.zero?(<<0::160>>)
      true

      iex> Address.zero?("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      false
  """
  @spec zero?(binary()) :: boolean()
  def zero?(address) do
    case to_binary(address) do
      {:ok, <<0::160>>} -> true
      _ -> false
    end
  end

  @doc """
  Returns the zero address as a 20-byte binary.

  ## Returns

  20-byte zero address.

  ## Examples

      iex> Address.zero()
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
  """
  @spec zero() :: binary()
  def zero, do: <<0::160>>

  @doc """
  Normalizes an address to binary format.

  Same as `to_binary/1` but raises on error instead of returning a tuple.

  ## Parameters

    * `address` - Address in various formats

  ## Returns

  20-byte address binary.

  ## Raises

  `ArgumentError` if the address is invalid.

  ## Examples

      iex> Address.normalize!("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      <<117, 103, 216, 59, 123, 141, 128, 173, 220, 178, 129, 167, 29, 84, 252, 123, 51, 100, 255, 237>>
  """
  @spec normalize!(binary()) :: binary()
  def normalize!(address) do
    case to_binary(address) do
      {:ok, binary} -> binary
      {:error, reason} -> raise ArgumentError, "Invalid address: #{reason}"
    end
  end
end
