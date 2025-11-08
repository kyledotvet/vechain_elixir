defmodule VeChain.Wallet.HD do
  @moduledoc """
  BIP32/BIP44 hierarchical deterministic wallet implementation for VeChain.

  This module provides functionality to:
  - Generate master keys from seed
  - Derive child keys following BIP32/BIP44 standards
  - Support VeChain's derivation path: m/44'/818'/0'/0
  - Generate multiple accounts and addresses

  ## VeChain Derivation Path

  VeChain follows BIP44 with coin type 818:
  - `m/44'/818'/0'/0/0` - First address of first account
  - `m/44'/818'/0'/0/1` - Second address of first account
  - `m/44'/818'/1'/0/0` - First address of second account

  Where:
  - 44' - BIP44 purpose (hardened)
  - 818' - VeChain coin type (hardened)
  - 0' - Account index (hardened)
  - 0 - Change (0 = external, 1 = internal)
  - 0 - Address index

  ## Examples

      # Generate master key from mnemonic
      mnemonic = VeChain.Wallet.Mnemonic.generate!()
      {:ok, seed} = VeChain.Wallet.Mnemonic.to_seed(mnemonic)
      {:ok, master_key} = VeChain.Wallet.HD.master_key_from_seed(seed)

      # Derive VeChain account
      {:ok, account_key} = VeChain.Wallet.HD.derive(master_key, "m/44'/818'/0'")

      # Derive first address
      {:ok, address_key} = VeChain.Wallet.HD.derive(account_key, "m/0/0")

      # Or use convenience function
      {:ok, address_key} = VeChain.Wallet.HD.derive_address(master_key, 0, 0)

      # Get private key and address
      private_key = VeChain.Wallet.HD.private_key(address_key)
      address = VeChain.Crypto.Address.from_private_key(private_key)

  ## Reference

  - BIP32: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
  - BIP44: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
  - VeChain Coin Type: 818 (registered in SLIP-0044)
  """

  alias VeChain.Crypto.Secp256k1
  alias VeChain.Wallet.Mnemonic

  @vechain_coin_type 818
  @hardened_offset 0x80000000

  @vet_derivation_path "m/44'/818'/0'/0"

  # Secp256k1 curve order
  @secp256k1_n 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

  @type extended_key :: %{
          private_key: binary(),
          chain_code: binary(),
          depth: non_neg_integer(),
          parent_fingerprint: binary(),
          child_index: non_neg_integer()
        }

  @type derivation_path :: String.t()
  @type mnemonic :: [String.t()]

  @doc """
  Generate master key from seed.

  Takes a seed (typically 64 bytes from BIP39) and generates the master
  extended private key.

  ## Examples

      {:ok, seed} = VeChain.Wallet.Mnemonic.to_seed(mnemonic)
      {:ok, master_key} = VeChain.Wallet.HD.master_key_from_seed(seed)
  """
  @spec master_key_from_seed(binary()) :: {:ok, extended_key()} | {:error, :invalid_seed}
  def master_key_from_seed(seed) when is_binary(seed) and byte_size(seed) >= 16 do
    # I = HMAC-SHA512(Key = "Bitcoin seed", Data = seed)
    <<private_key::binary-32, chain_code::binary-32>> =
      :crypto.mac(:hmac, :sha512, "Bitcoin seed", seed)

    # Verify private key is valid (0 < key < n)
    key_int = :binary.decode_unsigned(private_key, :big)

    if key_int > 0 and key_int < @secp256k1_n do
      {:ok,
       %{
         private_key: private_key,
         chain_code: chain_code,
         depth: 0,
         parent_fingerprint: <<0, 0, 0, 0>>,
         child_index: 0
       }}
    else
      # Invalid key, should regenerate (extremely unlikely)
      {:error, :invalid_seed}
    end
  end

  def master_key_from_seed(_), do: {:error, :invalid_seed}

  @doc """
  Generate master key from seed. Raises on error.

  ## Examples

      seed = VeChain.Wallet.Mnemonic.to_seed!(mnemonic)
      master_key = VeChain.Wallet.HD.master_key_from_seed!(seed)
  """
  @spec master_key_from_seed!(binary()) :: extended_key()
  def master_key_from_seed!(seed) do
    case master_key_from_seed(seed) do
      {:ok, key} -> key
      {:error, reason} -> raise ArgumentError, "Failed to generate master key: #{reason}"
    end
  end

  @doc """
  Derive child key from parent using a derivation path.

  Supports both absolute paths (starting with "m/") and relative paths.
  Hardened derivation is indicated by apostrophe (') after the index.

  ## Examples

      # Absolute path
      {:ok, key} = VeChain.Wallet.HD.derive(master_key, "m/44'/818'/0'/0/0")

      # Relative path
      {:ok, account_key} = VeChain.Wallet.HD.derive(master_key, "m/44'/818'/0'")
      {:ok, address_key} = VeChain.Wallet.HD.derive(account_key, "0/0")

      # Single index
      {:ok, child} = VeChain.Wallet.HD.derive(master_key, "0'")
  """
  @spec derive(extended_key(), derivation_path()) ::
          {:ok, extended_key()} | {:error, :invalid_path | :invalid_derivation}
  def derive(key, path) when is_map(key) and is_binary(path) do
    # Remove "m/" prefix if present
    path = String.replace_prefix(path, "m/", "")

    # Parse and derive
    case parse_path(path) do
      {:ok, indices} -> derive_indices(key, indices)
      error -> error
    end
  end

  @doc """
  Derive child key from parent. Raises on error.

  ## Examples

      key = VeChain.Wallet.HD.derive!(master_key, "m/44'/818'/0'/0/0")
  """
  @spec derive!(extended_key(), derivation_path()) :: extended_key()
  def derive!(key, path) do
    case derive(key, path) do
      {:ok, child} -> child
      {:error, reason} -> raise ArgumentError, "Failed to derive key: #{reason}"
    end
  end

  @doc """
  Derive VeChain address key using standard BIP44 path.

  Convenience function that derives: m/44'/818'/account'/change/address_index

  ## Parameters

  - `master_key` - Master extended key
  - `account` - Account index (default: 0)
  - `address_index` - Address index (default: 0)
  - `change` - Change index: 0 = external, 1 = internal (default: 0)

  ## Examples

      # First address of first account
      {:ok, key} = VeChain.Wallet.HD.derive_address(master_key, 0, 0)

      # Second address of first account
      {:ok, key} = VeChain.Wallet.HD.derive_address(master_key, 0, 1)

      # First address of second account
      {:ok, key} = VeChain.Wallet.HD.derive_address(master_key, 1, 0)
  """
  @spec derive_address(extended_key(), non_neg_integer(), non_neg_integer(), 0 | 1) ::
          {:ok, extended_key()} | {:error, term()}
  def derive_address(master_key, account \\ 0, address_index \\ 0, change \\ 0)
      when is_integer(account) and account >= 0 and is_integer(address_index) and
             address_index >= 0 and change in [0, 1] do
    path = "m/44'/#{@vechain_coin_type}'/#{account}'/#{change}/#{address_index}"
    derive(master_key, path)
  end

  @doc """
  Derive VeChain address key. Raises on error.

  ## Examples

      key = VeChain.Wallet.HD.derive_address!(master_key, 0, 0)
  """
  @spec derive_address!(extended_key(), non_neg_integer(), non_neg_integer(), 0 | 1) ::
          extended_key()
  def derive_address!(master_key, account \\ 0, address_index \\ 0, change \\ 0) do
    case derive_address(master_key, account, address_index, change) do
      {:ok, key} -> key
      {:error, reason} -> raise ArgumentError, "Failed to derive address: #{reason}"
    end
  end

  @doc """
  Get the private key from an extended key.

  ## Examples

      private_key = VeChain.Wallet.HD.private_key(extended_key)
      # => <<...>> (32 bytes)
  """
  @spec private_key(extended_key()) :: binary()
  def private_key(%{private_key: private_key}), do: private_key

  @doc """
  Get the public key from an extended key.

  Returns the uncompressed public key with 0x04 prefix (65 bytes).

  ## Examples

      public_key = VeChain.Wallet.HD.public_key(extended_key)
      # => <<4, ...>> (65 bytes, uncompressed)
  """
  @spec public_key(extended_key()) :: binary()
  def public_key(%{private_key: private_key}) do
    # Get 64-byte public key from Secp256k1 and add 0x04 prefix
    pub_key_64 = Secp256k1.private_key_to_public_key(private_key)
    <<0x04>> <> pub_key_64
  end

  @doc """
  Get the compressed public key from an extended key.

  ## Examples

      public_key = VeChain.Wallet.HD.public_key_compressed(extended_key)
      # => <<2, ...>> or <<3, ...>> (33 bytes)
  """
  @spec public_key_compressed(extended_key()) :: binary()
  def public_key_compressed(key) do
    key
    |> public_key()
    |> compress_public_key()
  end

  @doc """
  Get the VeChain address from an extended key.

  Returns the address as a hex string with "0x" prefix.

  ## Examples

      address = VeChain.Wallet.HD.address(extended_key)
      # => "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
  """
  @spec address(extended_key()) :: String.t()
  def address(key) do
    private_key = private_key(key)
    address_bytes = VeChain.Crypto.Address.from_private_key(private_key)
    "0x" <> Base.encode16(address_bytes, case: :lower)
  end

  @doc """
  Get the VeChain standard derivation path.

  Returns the standard BIP44 derivation path for VeChain: "m/44'/818'/0'/0"

  ## Examples

      VeChain.Wallet.HD.vet_derivation_path()
      # => "m/44'/818'/0'/0"
  """
  @spec vet_derivation_path() :: String.t()
  def vet_derivation_path, do: @vet_derivation_path

  @doc """
  Create an HDKey from mnemonic words and optional derivation path.

  This is a convenience function that combines seed generation and key derivation.

  ## Parameters

  - `mnemonic` - List of mnemonic words
  - `path` - Optional derivation path (default: "m/44'/818'/0'/0")
  - `passphrase` - Optional passphrase for seed generation (default: "")

  ## Examples

      words = ["ignore", "empty", "bird", ...]
      {:ok, key} = VeChain.Wallet.HD.from_mnemonic(words)

      # With custom path
      {:ok, key} = VeChain.Wallet.HD.from_mnemonic(words, "m/0/1")

      # With passphrase
      {:ok, key} = VeChain.Wallet.HD.from_mnemonic(words, "m/44'/818'/0'/0", "secret")
  """
  @spec from_mnemonic(mnemonic(), derivation_path(), String.t()) ::
          {:ok, extended_key()} | {:error, term()}
  def from_mnemonic(mnemonic, path \\ @vet_derivation_path, passphrase \\ "")
      when is_list(mnemonic) and is_binary(path) and is_binary(passphrase) do
    alias VeChain.Wallet.Mnemonic

    # Validate mnemonic before processing
    if not Mnemonic.valid?(mnemonic) do
      {:error, :invalid_mnemonic}
    else
      with {:ok, seed} <- Mnemonic.to_seed(mnemonic, passphrase),
           {:ok, master_key} <- master_key_from_seed(seed),
           {:ok, derived_key} <- derive(master_key, path) do
        {:ok, derived_key}
      end
    end
  end

  @doc """
  Create an HDKey from mnemonic words. Raises on error.

  ## Examples

      words = ["ignore", "empty", "bird", ...]
      key = VeChain.Wallet.HD.from_mnemonic!(words)
  """
  @spec from_mnemonic!(mnemonic(), derivation_path(), String.t()) :: extended_key()
  def from_mnemonic!(mnemonic, path \\ @vet_derivation_path, passphrase \\ "") do
    case from_mnemonic(mnemonic, path, passphrase) do
      {:ok, key} -> key
      {:error, reason} -> raise ArgumentError, "Failed to create HDKey from mnemonic: #{reason}"
    end
  end

  @doc """
  Derive a single child key by index.

  This derives a child key from the parent using a single index value.

  ## Parameters

  - `parent` - Parent extended key
  - `index` - Child index (use index >= 0x80000000 for hardened derivation)

  ## Examples

      # Normal derivation
      {:ok, child} = VeChain.Wallet.HD.derive_child(parent, 0)

      # Hardened derivation
      hardened_index = 0x80000000
      {:ok, child} = VeChain.Wallet.HD.derive_child(parent, hardened_index)
  """
  @spec derive_child(extended_key(), non_neg_integer()) ::
          {:ok, extended_key()} | {:error, :invalid_derivation}
  def derive_child(parent, index) when is_map(parent) and is_integer(index) and index >= 0 do
    hardened? = index >= @hardened_offset

    # Prepare data for HMAC
    data =
      if hardened? do
        # Hardened: ser256(kpar) = 0x00 || private_key (33 bytes)
        <<0>> <> parent.private_key <> <<index::32>>
      else
        # Normal: serP(point(kpar)) = compressed public key (33 bytes)
        compressed_pub =
          parent.private_key |> Secp256k1.private_key_to_public_key() |> compress_public_key()

        compressed_pub <> <<index::32>>
      end

    # I = HMAC-SHA512(Key = chain_code, Data = data)
    <<il::binary-32, ir::binary-32>> = :crypto.mac(:hmac, :sha512, parent.chain_code, data)

    # Parse IL as 256-bit integer
    il_int = :binary.decode_unsigned(il, :big)

    # Check if IL >= n (invalid, should try next index)
    if il_int >= @secp256k1_n do
      {:error, :invalid_derivation}
    else
      # ki = (parse256(IL) + kpar) mod n
      parent_key_int = :binary.decode_unsigned(parent.private_key, :big)
      child_key_int = rem(il_int + parent_key_int, @secp256k1_n)

      # Check if child key is zero (invalid)
      if child_key_int == 0 do
        {:error, :invalid_derivation}
      else
        child_private_key = :binary.encode_unsigned(child_key_int, :big) |> pad_to_32_bytes()

        {:ok,
         %{
           private_key: child_private_key,
           chain_code: ir,
           depth: parent.depth + 1,
           parent_fingerprint: fingerprint(parent),
           child_index: index
         }}
      end
    end
  end

  @doc """
  Derive a single child key by index. Raises on error.

  ## Examples

      child = VeChain.Wallet.HD.derive_child!(parent, 0)
  """
  @spec derive_child!(extended_key(), non_neg_integer()) :: extended_key()
  def derive_child!(parent, index) do
    case derive_child(parent, index) do
      {:ok, child} -> child
      {:error, reason} -> raise ArgumentError, "Failed to derive child: #{reason}"
    end
  end

  @doc """
  Get the fingerprint of an extended key.

  The fingerprint is the first 4 bytes of HASH160(compressed_public_key).

  ## Examples

      fingerprint = VeChain.Wallet.HD.fingerprint(extended_key)
      # => <<...>> (4 bytes)
  """
  @spec fingerprint(extended_key()) :: binary()
  def fingerprint(key) do
    compressed_pub = public_key_compressed(key)
    hash = hash160(compressed_pub)
    <<fingerprint::binary-4, _::binary>> = hash
    fingerprint
  end

  # Private functions

  defp parse_path(""), do: {:ok, []}

  defp parse_path(path) do
    path
    |> String.split("/")
    |> Enum.reduce_while({:ok, []}, fn segment, {:ok, acc} ->
      case parse_index(segment) do
        {:ok, index} -> {:cont, {:ok, acc ++ [index]}}
        error -> {:halt, error}
      end
    end)
  end

  defp parse_index(segment) do
    # Check for hardened derivation (apostrophe)
    {index_str, hardened?} =
      if String.ends_with?(segment, "'") do
        {String.trim_trailing(segment, "'"), true}
      else
        {segment, false}
      end

    case Integer.parse(index_str) do
      {index, ""} when index >= 0 ->
        final_index = if hardened?, do: index + @hardened_offset, else: index
        {:ok, final_index}

      _ ->
        {:error, :invalid_path}
    end
  end

  defp derive_indices(key, []), do: {:ok, key}

  defp derive_indices(key, [index | rest]) do
    case derive_child(key, index) do
      {:ok, child_key} -> derive_indices(child_key, rest)
      error -> error
    end
  end

  # Handle uncompressed public key with 0x04 prefix (65 bytes)
  defp compress_public_key(<<0x04::8, x::256, y::256>>) do
    # If y is even, prefix is 0x02, else 0x03
    prefix = if rem(y, 2) == 0, do: 0x02, else: 0x03
    <<prefix::8, x::256>>
  end

  # Handle uncompressed public key without prefix (64 bytes)
  defp compress_public_key(<<x::256, y::256>>) do
    # If y is even, prefix is 0x02, else 0x03
    prefix = if rem(y, 2) == 0, do: 0x02, else: 0x03
    <<prefix::8, x::256>>
  end

  defp hash160(data) do
    # HASH160 = RIPEMD160(SHA256(data))
    data
    |> then(&:crypto.hash(:sha256, &1))
    |> then(&:crypto.hash(:ripemd160, &1))
  end

  defp pad_to_32_bytes(binary) when byte_size(binary) >= 32 do
    # Take last 32 bytes if larger
    binary_size = byte_size(binary)
    <<_::binary-size(binary_size - 32), last_32::binary-32>> = binary
    last_32
  end

  defp pad_to_32_bytes(binary) do
    # Pad with leading zeros
    padding_size = (32 - byte_size(binary)) * 8
    <<0::size(padding_size), binary::binary>>
  end
end
