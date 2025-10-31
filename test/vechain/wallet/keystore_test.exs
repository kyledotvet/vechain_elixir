defmodule VeChain.Wallet.KeystoreTest do
  use ExUnit.Case, async: true

  alias VeChain.Wallet.Keystore

  @private_key :crypto.strong_rand_bytes(32)
  @password "test password 123"

  describe "encrypt/3" do
    test "encrypts private key with PBKDF2" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password)

      assert is_map(keystore)
      assert keystore.version == 3
      assert is_binary(keystore.id)
      assert keystore.crypto.cipher == "aes-128-ctr"
      assert keystore.crypto.kdf == "pbkdf2"
      assert is_map(keystore.crypto.kdfparams)
      assert is_binary(keystore.crypto.ciphertext)
      assert is_binary(keystore.crypto.mac)
    end

    test "encrypts private key with Scrypt" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password, kdf: :scrypt)

      assert keystore.crypto.kdf == "scrypt"
      assert is_map(keystore.crypto.kdfparams)
    end

    test "uses custom PBKDF2 iterations" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password, iterations: 100_000)

      assert keystore.crypto.kdfparams.c == 100_000
    end

    test "generates different ciphertext each time" do
      {:ok, keystore1} = Keystore.encrypt(@private_key, @password)
      {:ok, keystore2} = Keystore.encrypt(@private_key, @password)

      # Different salt and IV should produce different ciphertext
      assert keystore1.crypto.ciphertext != keystore2.crypto.ciphertext
      assert keystore1.crypto.kdfparams.salt != keystore2.crypto.kdfparams.salt
    end

    test "keystore structure is JSON serializable" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password)
      assert {:ok, _json} = Jason.encode(keystore)
    end
  end

  describe "encrypt!/3" do
    test "encrypts successfully" do
      keystore = Keystore.encrypt!(@private_key, @password)
      assert is_map(keystore)
    end
  end

  describe "decrypt/2" do
    test "decrypts keystore with correct password" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password)
      {:ok, decrypted_key} = Keystore.decrypt(keystore, @password)

      assert decrypted_key == @private_key
    end

    test "returns error with wrong password" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password)
      assert {:error, :invalid_password} = Keystore.decrypt(keystore, "wrong password")
    end

    test "works with Scrypt" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password, kdf: :scrypt)
      {:ok, decrypted_key} = Keystore.decrypt(keystore, @password)

      assert decrypted_key == @private_key
    end

    test "works with custom iterations" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password, iterations: 100_000)
      {:ok, decrypted_key} = Keystore.decrypt(keystore, @password)

      assert decrypted_key == @private_key
    end

    test "returns error for invalid keystore structure" do
      invalid_keystore = %{invalid: "structure"}
      assert {:error, :invalid_keystore} = Keystore.decrypt(invalid_keystore, @password)
    end

    test "returns error for corrupted ciphertext" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password)

      # Corrupt the ciphertext
      corrupted_keystore = put_in(keystore.crypto.ciphertext, "deadbeef")
      assert {:error, :invalid_password} = Keystore.decrypt(corrupted_keystore, @password)
    end

    test "returns error for corrupted MAC" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password)

      # Corrupt the MAC
      corrupted_keystore = put_in(keystore.crypto.mac, "deadbeef")
      assert {:error, :invalid_password} = Keystore.decrypt(corrupted_keystore, @password)
    end
  end

  describe "decrypt!/2" do
    test "decrypts successfully" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password)
      decrypted_key = Keystore.decrypt!(keystore, @password)
      assert decrypted_key == @private_key
    end

    test "raises on wrong password" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password)

      assert_raise ArgumentError, fn ->
        Keystore.decrypt!(keystore, "wrong password")
      end
    end
  end

  describe "encrypt_to_file/4 and decrypt_from_file/2" do
    @tag :tmp_dir
    test "encrypts and decrypts from file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "keystore.json")

      # Encrypt to file
      assert :ok = Keystore.encrypt_to_file(@private_key, @password, path)
      assert File.exists?(path)

      # File should contain valid JSON
      {:ok, content} = File.read(path)
      {:ok, _keystore} = Jason.decode(content)

      # Decrypt from file
      {:ok, decrypted_key} = Keystore.decrypt_from_file(path, @password)
      assert decrypted_key == @private_key
    end

    @tag :tmp_dir
    test "returns error for non-existent file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "nonexistent.json")
      assert {:error, :file_error} = Keystore.decrypt_from_file(path, @password)
    end

    @tag :tmp_dir
    test "returns error for invalid JSON file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "invalid.json")
      File.write!(path, "invalid json content")

      assert {:error, :file_error} = Keystore.decrypt_from_file(path, @password)
    end
  end

  describe "round-trip encryption/decryption" do
    test "preserves key through multiple encryptions" do
      # Encrypt with PBKDF2
      {:ok, keystore1} = Keystore.encrypt(@private_key, @password)
      {:ok, key1} = Keystore.decrypt(keystore1, @password)
      assert key1 == @private_key

      # Encrypt with Scrypt
      {:ok, keystore2} = Keystore.encrypt(@private_key, @password, kdf: :scrypt)
      {:ok, key2} = Keystore.decrypt(keystore2, @password)
      assert key2 == @private_key

      # Encrypt with custom iterations
      {:ok, keystore3} = Keystore.encrypt(@private_key, @password, iterations: 50_000)
      {:ok, key3} = Keystore.decrypt(keystore3, @password)
      assert key3 == @private_key
    end

    test "works with all 32-byte keys" do
      keys = [
        <<0::256>>,
        <<255::256>>,
        :crypto.strong_rand_bytes(32),
        :crypto.strong_rand_bytes(32)
      ]

      Enum.each(keys, fn key ->
        {:ok, keystore} = Keystore.encrypt(key, @password)
        {:ok, decrypted} = Keystore.decrypt(keystore, @password)
        assert decrypted == key
      end)
    end

    test "different passwords produce different keystores" do
      {:ok, keystore1} = Keystore.encrypt(@private_key, "password1")
      {:ok, keystore2} = Keystore.encrypt(@private_key, "password2")

      # Cannot decrypt with wrong password
      assert {:error, :invalid_password} = Keystore.decrypt(keystore1, "password2")
      assert {:error, :invalid_password} = Keystore.decrypt(keystore2, "password1")

      # Can decrypt with correct passwords
      {:ok, key1} = Keystore.decrypt(keystore1, "password1")
      {:ok, key2} = Keystore.decrypt(keystore2, "password2")
      assert key1 == @private_key
      assert key2 == @private_key
    end
  end

  describe "compatibility" do
    test "keystore has all required Web3 Secret Storage fields" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password)

      # Top level fields
      assert Map.has_key?(keystore, :crypto)
      assert Map.has_key?(keystore, :id)
      assert Map.has_key?(keystore, :version)

      # Crypto fields
      crypto = keystore.crypto
      assert Map.has_key?(crypto, :cipher)
      assert Map.has_key?(crypto, :cipherparams)
      assert Map.has_key?(crypto, :ciphertext)
      assert Map.has_key?(crypto, :kdf)
      assert Map.has_key?(crypto, :kdfparams)
      assert Map.has_key?(crypto, :mac)

      # Cipher params
      assert Map.has_key?(crypto.cipherparams, :iv)

      # KDF params (PBKDF2)
      kdfparams = crypto.kdfparams
      assert Map.has_key?(kdfparams, :c)
      assert Map.has_key?(kdfparams, :dklen)
      assert Map.has_key?(kdfparams, :prf)
      assert Map.has_key?(kdfparams, :salt)
    end

    test "all hex fields are lowercase" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password)

      # Check hex strings are lowercase
      assert keystore.crypto.ciphertext == String.downcase(keystore.crypto.ciphertext)
      assert keystore.crypto.mac == String.downcase(keystore.crypto.mac)
      assert keystore.crypto.cipherparams.iv == String.downcase(keystore.crypto.cipherparams.iv)
      assert keystore.crypto.kdfparams.salt == String.downcase(keystore.crypto.kdfparams.salt)
    end

    test "UUID is valid format" do
      {:ok, keystore} = Keystore.encrypt(@private_key, @password)

      # UUID should be in format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      assert keystore.id =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
    end
  end
end
