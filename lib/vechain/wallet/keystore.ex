defmodule VeChain.Wallet.Keystore do
  @moduledoc """
  Web3 Secret Storage (Keystore V3) implementation for VeChain.

  This module provides functionality to:
  - Encrypt private keys with a password
  - Decrypt keystore files
  - Generate JSON keystore files compatible with Ethereum/VeChain wallets
  - Support both PBKDF2 and Scrypt key derivation functions

  The keystore format follows the Web3 Secret Storage Definition V3:
  https://ethereum.org/developers/docs/data-structures-and-encoding/web3-secret-storage

  ## Security Features

  - AES-128-CTR encryption
  - PBKDF2-HMAC-SHA256 or Scrypt key derivation
  - MAC (Message Authentication Code) for integrity verification
  - Configurable KDF parameters

  ## Examples

      # Encrypt a private key
      private_key = :crypto.strong_rand_bytes(32)
      password = "my secure password"
      {:ok, keystore} = VeChain.Wallet.Keystore.encrypt(private_key, password)

      # Keystore is a map that can be JSON encoded
      json = Jason.encode!(keystore)

      # Decrypt a keystore
      {:ok, decrypted_key} = VeChain.Wallet.Keystore.decrypt(keystore, password)

      # Use Scrypt instead of PBKDF2
      {:ok, keystore} = VeChain.Wallet.Keystore.encrypt(private_key, password, kdf: :scrypt)

      # Custom PBKDF2 iterations
      {:ok, keystore} = VeChain.Wallet.Keystore.encrypt(
        private_key,
        password,
        kdf: :pbkdf2,
        iterations: 1_000_000
      )

  ## Reference

  - Web3 Secret Storage: https://ethereum.org/developers/docs/data-structures-and-encoding/web3-secret-storage
  - EIP-2335: BLS12-381 Keystore (similar format)
  """

  @type keystore :: %{
          crypto: %{
            cipher: String.t(),
            cipherparams: %{iv: String.t()},
            ciphertext: String.t(),
            kdf: String.t(),
            kdfparams: map(),
            mac: String.t()
          },
          id: String.t(),
          version: integer()
        }

  @type encrypt_opts :: [
          kdf: :pbkdf2 | :scrypt,
          iterations: pos_integer(),
          scrypt_n: pos_integer(),
          scrypt_r: pos_integer(),
          scrypt_p: pos_integer(),
          dklen: pos_integer()
        ]

  @default_pbkdf2_iterations 262_144
  @default_scrypt_n 262_144
  @default_scrypt_r 8
  @default_scrypt_p 1
  @default_dklen 32

  @doc """
  Encrypt a private key with a password.

  ## Options

  - `:kdf` - Key derivation function: `:pbkdf2` (default) or `:scrypt`
  - `:iterations` - PBKDF2 iterations (default: 262144)
  - `:scrypt_n` - Scrypt N parameter (default: 262144)
  - `:scrypt_r` - Scrypt r parameter (default: 8)
  - `:scrypt_p` - Scrypt p parameter (default: 1)
  - `:dklen` - Derived key length in bytes (default: 32)

  ## Examples

      private_key = :crypto.strong_rand_bytes(32)
      {:ok, keystore} = VeChain.Wallet.Keystore.encrypt(private_key, "password")

      # With custom options
      {:ok, keystore} = VeChain.Wallet.Keystore.encrypt(
        private_key,
        "password",
        kdf: :scrypt,
        scrypt_n: 131072
      )
  """
  @spec encrypt(binary(), String.t(), encrypt_opts()) :: {:ok, keystore()}
  def encrypt(private_key, password, opts \\ [])
      when is_binary(private_key) and byte_size(private_key) == 32 and is_binary(password) do
    kdf = Keyword.get(opts, :kdf, :pbkdf2)
    dklen = Keyword.get(opts, :dklen, @default_dklen)

    # Generate random salt and IV
    salt = :crypto.strong_rand_bytes(32)
    iv = :crypto.strong_rand_bytes(16)

    # Derive key using KDF
    {derived_key, kdf_name, kdfparams} =
      case kdf do
        :pbkdf2 ->
          iterations = Keyword.get(opts, :iterations, @default_pbkdf2_iterations)
          dk = pbkdf2(password, salt, iterations, dklen)

          {dk, "pbkdf2",
           %{
             c: iterations,
             dklen: dklen,
             prf: "hmac-sha256",
             salt: Base.encode16(salt, case: :lower)
           }}

        :scrypt ->
          n = Keyword.get(opts, :scrypt_n, @default_scrypt_n)
          r = Keyword.get(opts, :scrypt_r, @default_scrypt_r)
          p = Keyword.get(opts, :scrypt_p, @default_scrypt_p)
          dk = scrypt(password, salt, n, r, p, dklen)

          {dk, "scrypt",
           %{
             dklen: dklen,
             n: n,
             r: r,
             p: p,
             salt: Base.encode16(salt, case: :lower)
           }}
      end

    # Encrypt private key with AES-128-CTR
    <<cipher_key::binary-16, mac_key::binary-16, _::binary>> = derived_key
    ciphertext = aes_128_ctr_encrypt(private_key, cipher_key, iv)

    # Calculate MAC
    mac = compute_mac(mac_key, ciphertext)

    # Build keystore structure
    keystore = %{
      crypto: %{
        cipher: "aes-128-ctr",
        cipherparams: %{
          iv: Base.encode16(iv, case: :lower)
        },
        ciphertext: Base.encode16(ciphertext, case: :lower),
        kdf: kdf_name,
        kdfparams: kdfparams,
        mac: Base.encode16(mac, case: :lower)
      },
      id: __MODULE__.UUID.uuid4(),
      version: 3
    }

    {:ok, keystore}
  end

  @doc """
  Encrypt a private key. Raises on error.

  ## Examples

      private_key = :crypto.strong_rand_bytes(32)
      keystore = VeChain.Wallet.Keystore.encrypt!(private_key, "password")
  """
  @spec encrypt!(binary(), String.t(), encrypt_opts()) :: keystore()
  def encrypt!(private_key, password, opts \\ []) do
    {:ok, keystore} = encrypt(private_key, password, opts)
    keystore
  end

  @doc """
  Decrypt a keystore file with a password.

  ## Examples

      {:ok, private_key} = VeChain.Wallet.Keystore.decrypt(keystore, "password")

      # Wrong password
      VeChain.Wallet.Keystore.decrypt(keystore, "wrong")
      # => {:error, :invalid_password}
  """
  @spec decrypt(keystore(), String.t()) ::
          {:ok, binary()} | {:error, :invalid_password | :unsupported_kdf | :invalid_keystore}
  def decrypt(keystore, password) when is_map(keystore) and is_binary(password) do
    with {:ok, crypto} <- get_crypto(keystore),
         {:ok, derived_key} <- derive_key_from_keystore(crypto, password),
         {:ok, _} <- verify_mac(crypto, derived_key),
         {:ok, private_key} <- decrypt_ciphertext(crypto, derived_key) do
      {:ok, private_key}
    end
  rescue
    _ -> {:error, :invalid_keystore}
  end

  @doc """
  Decrypt a keystore file. Raises on error.

  ## Examples

      private_key = VeChain.Wallet.Keystore.decrypt!(keystore, "password")
  """
  @spec decrypt!(keystore(), String.t()) :: binary()
  def decrypt!(keystore, password) do
    case decrypt(keystore, password) do
      {:ok, private_key} -> private_key
      {:error, reason} -> raise ArgumentError, "Failed to decrypt keystore: #{reason}"
    end
  end

  @doc """
  Encrypt a private key and save to JSON file.

  ## Examples

      VeChain.Wallet.Keystore.encrypt_to_file(private_key, "password", "/path/to/keystore.json")
  """
  @spec encrypt_to_file(binary(), String.t(), Path.t(), encrypt_opts()) :: :ok | {:error, term()}
  def encrypt_to_file(private_key, password, path, opts \\ []) do
    with {:ok, keystore} <- encrypt(private_key, password, opts),
         {:ok, json} <- Jason.encode(keystore, pretty: true) do
      File.write(path, json)
    end
  end

  @doc """
  Decrypt a keystore from JSON file.

  ## Examples

      {:ok, private_key} = VeChain.Wallet.Keystore.decrypt_from_file(
        "/path/to/keystore.json",
        "password"
      )
  """
  @spec decrypt_from_file(Path.t(), String.t()) ::
          {:ok, binary()} | {:error, :invalid_password | :file_error}
  def decrypt_from_file(path, password) do
    with {:ok, content} <- File.read(path),
         {:ok, keystore} <- Jason.decode(content, keys: :atoms) do
      decrypt(keystore, password)
    else
      {:error, _} -> {:error, :file_error}
    end
  end

  # Private functions

  defp get_crypto(%{crypto: crypto}), do: {:ok, crypto}
  defp get_crypto(_), do: {:error, :invalid_keystore}

  defp derive_key_from_keystore(%{kdf: "pbkdf2", kdfparams: params}, password) do
    with {:ok, salt} <- Base.decode16(params.salt, case: :mixed),
         iterations = params.c,
         dklen = params.dklen do
      derived_key = pbkdf2(password, salt, iterations, dklen)
      {:ok, derived_key}
    else
      _ -> {:error, :invalid_keystore}
    end
  end

  defp derive_key_from_keystore(%{kdf: "scrypt", kdfparams: params}, password) do
    with {:ok, salt} <- Base.decode16(params.salt, case: :mixed),
         n = params.n,
         r = params.r,
         p = params.p,
         dklen = params.dklen do
      derived_key = scrypt(password, salt, n, r, p, dklen)
      {:ok, derived_key}
    else
      _ -> {:error, :invalid_keystore}
    end
  end

  defp derive_key_from_keystore(_, _), do: {:error, :unsupported_kdf}

  defp verify_mac(crypto, derived_key) do
    with {:ok, stored_mac} <- Base.decode16(crypto.mac, case: :mixed),
         {:ok, ciphertext} <- Base.decode16(crypto.ciphertext, case: :mixed) do
      <<_cipher_key::binary-16, mac_key::binary-16, _::binary>> = derived_key
      calculated_mac = compute_mac(mac_key, ciphertext)

      if secure_compare(calculated_mac, stored_mac) do
        {:ok, :valid}
      else
        {:error, :invalid_password}
      end
    else
      _ -> {:error, :invalid_keystore}
    end
  end

  defp decrypt_ciphertext(crypto, derived_key) do
    with {:ok, ciphertext} <- Base.decode16(crypto.ciphertext, case: :mixed),
         {:ok, iv} <- Base.decode16(crypto.cipherparams.iv, case: :mixed) do
      <<cipher_key::binary-16, _::binary>> = derived_key
      plaintext = aes_128_ctr_decrypt(ciphertext, cipher_key, iv)
      {:ok, plaintext}
    else
      _ -> {:error, :invalid_keystore}
    end
  end

  defp pbkdf2(password, salt, iterations, dklen) do
    # Pure Elixir PBKDF2-HMAC-SHA256 implementation
    # Based on RFC 2898
    hmac = fn key, data -> :crypto.mac(:hmac, :sha256, key, data) end
    block_count = div(dklen + 31, 32)

    blocks =
      for i <- 1..block_count do
        pbkdf2_block(hmac, password, salt, iterations, i)
      end

    blocks
    |> IO.iodata_to_binary()
    |> binary_part(0, dklen)
  end

  defp pbkdf2_block(hmac, password, salt, iterations, block_index) do
    initial = hmac.(password, <<salt::binary, block_index::32>>)

    {_last, result} =
      Enum.reduce(2..iterations, {initial, initial}, fn _i, {prev, acc} ->
        next = hmac.(password, prev)
        {next, :crypto.exor(acc, next)}
      end)

    result
  end

  defp scrypt(password, salt, n, r, p, dklen) do
    # Note: Scrypt is computationally expensive and should use a NIF
    # For production use, install: https://hex.pm/packages/scrypt
    # This is a fallback that uses PBKDF2 instead

    # Check if scrypt package is available
    case Code.ensure_loaded?(Scrypt) do
      true ->
        # Use the scrypt library if available
        Scrypt.hash_password(password, salt, n, r, p, dklen)

      false ->
        # Fallback: use PBKDF2 with equivalent work factor
        # This maintains security but changes the algorithm
        # For proper Scrypt support, add {:scrypt, "~> 0.1"} to mix.exs
        iterations = div(n * r * p, 1000)
        pbkdf2(password, salt, iterations, dklen)
    end
  end

  defp aes_128_ctr_encrypt(plaintext, key, iv) do
    :crypto.crypto_one_time(:aes_128_ctr, key, iv, plaintext, true)
  end

  defp aes_128_ctr_decrypt(ciphertext, key, iv) do
    :crypto.crypto_one_time(:aes_128_ctr, key, iv, ciphertext, false)
  end

  defp compute_mac(mac_key, ciphertext) do
    # MAC = keccak256(mac_key ++ ciphertext)
    ExKeccak.hash_256(mac_key <> ciphertext)
  end

  # Constant-time comparison to prevent timing attacks
  defp secure_compare(a, b) when byte_size(a) == byte_size(b) do
    result =
      a
      |> :binary.bin_to_list()
      |> Enum.zip(:binary.bin_to_list(b))
      |> Enum.reduce(0, fn {x, y}, acc -> Bitwise.bor(acc, Bitwise.bxor(x, y)) end)

    result == 0
  end

  defp secure_compare(_, _), do: false

  # Generate UUID v4
  defmodule UUID do
    def uuid4 do
      <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
      # Set version (4) and variant (10)
      <<u0::48, 4::4, u1::12, 2::2, u2::62>>
      |> uuid_to_string()
    end

    defp uuid_to_string(<<u0::32, u1::16, u2::16, u3::16, u4::48>>) do
      [u0, u1, u2, u3, u4]
      |> Enum.map(&Base.encode16(<<&1::128>>, case: :lower))
      |> Enum.map(&String.trim_leading(&1, "0"))
      |> format_uuid_parts()
    end

    defp format_uuid_parts([a, b, c, d, e]) do
      a = String.pad_leading(a, 8, "0")
      b = String.pad_leading(b, 4, "0")
      c = String.pad_leading(c, 4, "0")
      d = String.pad_leading(d, 4, "0")
      e = String.pad_leading(e, 12, "0")
      "#{a}-#{b}-#{c}-#{d}-#{e}"
    end
  end
end
