defmodule VeChain.Wallet.HDTest do
  use ExUnit.Case, async: true

  alias VeChain.Wallet.{HD, Mnemonic}

  describe "master_key_from_seed/1" do
    test "generates master key from seed" do
      seed = :crypto.strong_rand_bytes(64)
      {:ok, master_key} = HD.master_key_from_seed(seed)

      assert is_map(master_key)
      assert byte_size(master_key.private_key) == 32
      assert byte_size(master_key.chain_code) == 32
      assert master_key.depth == 0
      assert master_key.parent_fingerprint == <<0, 0, 0, 0>>
      assert master_key.child_index == 0
    end

    test "generates same master key for same seed" do
      seed = :crypto.strong_rand_bytes(64)
      {:ok, master_key1} = HD.master_key_from_seed(seed)
      {:ok, master_key2} = HD.master_key_from_seed(seed)

      assert master_key1 == master_key2
    end

    test "returns error for too-short seed" do
      short_seed = :crypto.strong_rand_bytes(8)
      assert {:error, :invalid_seed} = HD.master_key_from_seed(short_seed)
    end

    test "works with BIP32 test vector 1" do
      # Test vector 1 from BIP32
      seed = Base.decode16!("000102030405060708090a0b0c0d0e0f", case: :lower)
      {:ok, master_key} = HD.master_key_from_seed(seed)

      # Expected master private key
      expected_key =
        "e8f32e723decf4051aefac8e2c93c9c5b214313817cdb01a1494b917c8436b35"

      assert Base.encode16(master_key.private_key, case: :lower) == expected_key

      # Expected chain code
      expected_chain_code =
        "873dff81c02f525623fd1fe5167eac3a55a049de3d314bb42ee227ffed37d508"

      assert Base.encode16(master_key.chain_code, case: :lower) == expected_chain_code
    end
  end

  describe "master_key_from_seed!/1" do
    test "returns master key without tuple" do
      seed = :crypto.strong_rand_bytes(64)
      master_key = HD.master_key_from_seed!(seed)
      assert is_map(master_key)
    end

    test "raises on invalid seed" do
      assert_raise ArgumentError, fn ->
        HD.master_key_from_seed!(<<1, 2, 3>>)
      end
    end
  end

  describe "derive/2" do
    setup do
      seed = :crypto.strong_rand_bytes(64)
      {:ok, master_key} = HD.master_key_from_seed(seed)
      %{master_key: master_key}
    end

    test "derives child with single index", %{master_key: master_key} do
      {:ok, child} = HD.derive(master_key, "0")
      assert child.depth == 1
      assert child.child_index == 0
    end

    test "derives hardened child", %{master_key: master_key} do
      {:ok, child} = HD.derive(master_key, "0'")
      assert child.depth == 1
      assert child.child_index >= 0x80000000
    end

    test "derives path with multiple indices", %{master_key: master_key} do
      {:ok, child} = HD.derive(master_key, "m/0/1/2")
      assert child.depth == 3
      assert child.child_index == 2
    end

    test "derives path with hardened indices", %{master_key: master_key} do
      {:ok, child} = HD.derive(master_key, "m/44'/818'/0'")
      assert child.depth == 3
      assert child.child_index >= 0x80000000
    end

    test "derives relative path", %{master_key: master_key} do
      {:ok, account} = HD.derive(master_key, "m/44'/818'/0'")
      {:ok, address} = HD.derive(account, "0/0")
      assert address.depth == 5
    end

    test "returns same child for same path", %{master_key: master_key} do
      {:ok, child1} = HD.derive(master_key, "m/44'/818'/0'/0/0")
      {:ok, child2} = HD.derive(master_key, "m/44'/818'/0'/0/0")
      assert child1 == child2
    end

    test "returns error for invalid path", %{master_key: master_key} do
      assert {:error, :invalid_path} = HD.derive(master_key, "m/invalid")
      assert {:error, :invalid_path} = HD.derive(master_key, "m/-1")
    end

    test "works with BIP32 test vector 1" do
      # Test vector 1 from BIP32
      seed = Base.decode16!("000102030405060708090a0b0c0d0e0f", case: :lower)
      {:ok, master_key} = HD.master_key_from_seed(seed)

      # Derive m/0'
      {:ok, child} = HD.derive(master_key, "m/0'")

      expected_key =
        "edb2e14f9ee77d26dd93b4ecede8d16ed408ce149b6cd80b0715a2d911a0afea"

      assert Base.encode16(child.private_key, case: :lower) == expected_key
    end
  end

  describe "derive!/2" do
    test "returns child without tuple" do
      seed = :crypto.strong_rand_bytes(64)
      master_key = HD.master_key_from_seed!(seed)
      child = HD.derive!(master_key, "0")
      assert is_map(child)
    end

    test "raises on invalid path" do
      seed = :crypto.strong_rand_bytes(64)
      master_key = HD.master_key_from_seed!(seed)

      assert_raise ArgumentError, fn ->
        HD.derive!(master_key, "invalid")
      end
    end
  end

  describe "derive_address/4" do
    setup do
      seed = :crypto.strong_rand_bytes(64)
      {:ok, master_key} = HD.master_key_from_seed(seed)
      %{master_key: master_key}
    end

    test "derives first address of first account", %{master_key: master_key} do
      {:ok, address_key} = HD.derive_address(master_key, 0, 0)
      assert address_key.depth == 5
      # Path: m/44'/818'/0'/0/0
    end

    test "derives second address of first account", %{master_key: master_key} do
      {:ok, address_key} = HD.derive_address(master_key, 0, 1)
      assert address_key.depth == 5
      assert address_key.child_index == 1
    end

    test "derives first address of second account", %{master_key: master_key} do
      {:ok, address_key} = HD.derive_address(master_key, 1, 0)
      assert address_key.depth == 5
      # Account index should be hardened
    end

    test "derives change address", %{master_key: master_key} do
      {:ok, address_key} = HD.derive_address(master_key, 0, 0, 1)
      assert address_key.depth == 5
      # Change index is 1
    end

    test "returns same address for same indices", %{master_key: master_key} do
      {:ok, key1} = HD.derive_address(master_key, 0, 0)
      {:ok, key2} = HD.derive_address(master_key, 0, 0)
      assert key1 == key2
    end

    test "returns different addresses for different indices", %{master_key: master_key} do
      {:ok, key1} = HD.derive_address(master_key, 0, 0)
      {:ok, key2} = HD.derive_address(master_key, 0, 1)
      assert key1 != key2
    end
  end

  describe "derive_address!/4" do
    test "returns address key without tuple" do
      seed = :crypto.strong_rand_bytes(64)
      master_key = HD.master_key_from_seed!(seed)
      address_key = HD.derive_address!(master_key, 0, 0)
      assert is_map(address_key)
    end
  end

  describe "private_key/1" do
    test "returns private key from extended key" do
      seed = :crypto.strong_rand_bytes(64)
      {:ok, master_key} = HD.master_key_from_seed(seed)
      private_key = HD.private_key(master_key)
      assert is_binary(private_key)
      assert byte_size(private_key) == 32
    end
  end

  describe "public_key/1" do
    test "returns uncompressed public key" do
      seed = :crypto.strong_rand_bytes(64)
      {:ok, master_key} = HD.master_key_from_seed(seed)
      public_key = HD.public_key(master_key)
      assert is_binary(public_key)
      assert byte_size(public_key) == 65
      # Uncompressed public key starts with 0x04
      assert <<0x04, _::binary-64>> = public_key
    end
  end

  describe "public_key_compressed/1" do
    test "returns compressed public key" do
      seed = :crypto.strong_rand_bytes(64)
      {:ok, master_key} = HD.master_key_from_seed(seed)
      public_key = HD.public_key_compressed(master_key)
      assert is_binary(public_key)
      assert byte_size(public_key) == 33
      # Compressed key starts with 0x02 or 0x03
      <<prefix, _::binary-32>> = public_key
      assert prefix in [0x02, 0x03]
    end
  end

  describe "address/1" do
    test "returns VeChain address" do
      seed = :crypto.strong_rand_bytes(64)
      {:ok, master_key} = HD.master_key_from_seed(seed)
      address = HD.address(master_key)
      assert is_binary(address)
      assert String.starts_with?(address, "0x")
      assert String.length(address) == 42
    end

    test "returns same address for same key" do
      seed = :crypto.strong_rand_bytes(64)
      {:ok, master_key} = HD.master_key_from_seed(seed)
      address1 = HD.address(master_key)
      address2 = HD.address(master_key)
      assert address1 == address2
    end
  end

  describe "fingerprint/1" do
    test "returns 4-byte fingerprint" do
      seed = :crypto.strong_rand_bytes(64)
      {:ok, master_key} = HD.master_key_from_seed(seed)
      fingerprint = HD.fingerprint(master_key)
      assert is_binary(fingerprint)
      assert byte_size(fingerprint) == 4
    end

    test "child has correct parent fingerprint" do
      seed = :crypto.strong_rand_bytes(64)
      {:ok, master_key} = HD.master_key_from_seed(seed)
      parent_fingerprint = HD.fingerprint(master_key)

      {:ok, child} = HD.derive(master_key, "0")
      assert child.parent_fingerprint == parent_fingerprint
    end
  end

  describe "full wallet workflow" do
    test "generates deterministic wallet from mnemonic" do
      # Generate mnemonic
      {:ok, mnemonic} = Mnemonic.generate()

      # Generate seed
      {:ok, seed} = Mnemonic.to_seed(mnemonic)

      # Generate master key
      {:ok, master_key} = HD.master_key_from_seed(seed)

      # Derive first 5 addresses
      addresses =
        for i <- 0..4 do
          {:ok, key} = HD.derive_address(master_key, 0, i)
          HD.address(key)
        end

      # All addresses should be unique
      assert length(Enum.uniq(addresses)) == 5

      # All addresses should be valid format
      Enum.each(addresses, fn addr ->
        assert String.starts_with?(addr, "0x")
        assert String.length(addr) == 42
      end)

      # Regenerating from same mnemonic should give same addresses
      {:ok, seed2} = Mnemonic.to_seed(mnemonic)
      {:ok, master_key2} = HD.master_key_from_seed(seed2)
      {:ok, first_key2} = HD.derive_address(master_key2, 0, 0)

      {:ok, first_key1} = HD.derive_address(master_key, 0, 0)
      assert first_key1 == first_key2
      assert HD.address(first_key1) == HD.address(first_key2)
    end
  end

  describe "from_mnemonic/3" do
    setup do
      {:ok, mnemonic} = Mnemonic.generate()
      %{mnemonic: mnemonic}
    end

    test "creates HDKey from mnemonic with default path", %{mnemonic: mnemonic} do
      {:ok, key} = HD.from_mnemonic(mnemonic)
      assert is_map(key)
      assert byte_size(key.private_key) == 32
      # Default path "m/44'/818'/0'/0" has depth 4
      assert key.depth == 4
    end

    test "creates HDKey from mnemonic with custom path", %{mnemonic: mnemonic} do
      {:ok, key} = HD.from_mnemonic(mnemonic, "m/0/1")
      assert is_map(key)
      assert key.depth == 2
    end

    test "creates HDKey from mnemonic with passphrase", %{mnemonic: mnemonic} do
      {:ok, key1} = HD.from_mnemonic(mnemonic, HD.vet_derivation_path(), "")
      {:ok, key2} = HD.from_mnemonic(mnemonic, HD.vet_derivation_path(), "passphrase")

      # Different passphrases should yield different keys
      refute key1.private_key == key2.private_key
    end

    test "returns same key as manual derivation", %{mnemonic: mnemonic} do
      # Using from_mnemonic
      {:ok, key1} = HD.from_mnemonic(mnemonic, "m/44'/818'/0'/0/0")

      # Using manual process
      {:ok, seed} = Mnemonic.to_seed(mnemonic)
      {:ok, master} = HD.master_key_from_seed(seed)
      {:ok, key2} = HD.derive(master, "m/44'/818'/0'/0/0")

      assert key1 == key2
    end
  end

  describe "from_mnemonic!/3" do
    test "returns key without tuple" do
      {:ok, mnemonic} = Mnemonic.generate()
      key = HD.from_mnemonic!(mnemonic)
      assert is_map(key)
    end

    test "raises on invalid mnemonic" do
      assert_raise ArgumentError, fn ->
        HD.from_mnemonic!(["invalid", "words"])
      end
    end
  end

  describe "derive_child/2" do
    setup do
      {:ok, mnemonic} = Mnemonic.generate()
      {:ok, master} = HD.from_mnemonic(mnemonic, "m/44'/818'/0'/0")
      %{master: master}
    end

    test "derives normal child by index", %{master: master} do
      {:ok, child} = HD.derive_child(master, 0)
      assert child.depth == master.depth + 1
      assert child.child_index == 0
      assert child.parent_fingerprint == HD.fingerprint(master)
    end

    test "derives hardened child by index", %{master: master} do
      hardened_index = 0x80000000
      {:ok, child} = HD.derive_child(master, hardened_index)
      assert child.depth == master.depth + 1
      assert child.child_index == hardened_index
    end

    test "derives multiple children with different keys", %{master: master} do
      children =
        for i <- 0..4 do
          {:ok, child} = HD.derive_child(master, i)
          child
        end

      # All should have different private keys
      private_keys = Enum.map(children, & &1.private_key)
      assert length(Enum.uniq(private_keys)) == 5

      # All should have correct parent
      Enum.each(children, fn child ->
        assert child.parent_fingerprint == HD.fingerprint(master)
      end)
    end

    test "derive_child matches derive with path", %{master: master} do
      # Derive using derive_child
      {:ok, child1} = HD.derive_child(master, 5)

      # Derive using path
      {:ok, child2} = HD.derive(master, "5")

      assert child1 == child2
    end
  end

  describe "derive_child!/2" do
    test "returns child without tuple" do
      {:ok, mnemonic} = Mnemonic.generate()
      {:ok, master} = HD.from_mnemonic(mnemonic, "m/44'/818'/0'/0")
      child = HD.derive_child!(master, 0)
      assert is_map(child)
    end
  end

  describe "vet_derivation_path/0" do
    test "returns VeChain standard derivation path" do
      assert HD.vet_derivation_path() == "m/44'/818'/0'/0"
    end
  end
end
