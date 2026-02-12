defmodule VeChain.ConfigurationTest do
  use ExUnit.Case, async: true

  describe "get_network/1" do
    test "returns mainnet config" do
      assert VeChain.Configuration.get_network(:mainnet) == %{chain_tag: <<0x4A>>}
    end

    test "returns testnet config" do
      assert VeChain.Configuration.get_network(:testnet) == %{chain_tag: <<0x27>>}
    end

    test "returns custom config from application environment" do
      custom_config = %{chain_tag: <<0xFF>>}
      Application.put_env(:vechain, :network_config, custom_config)
      assert VeChain.Configuration.get_network(:custom) == custom_config
      Application.delete_env(:vechain, :network_config)
    end

    test "returns solo config from application environment" do
      solo_config = %{chain_tag: <<0xAB>>}
      Application.put_env(:vechain, :network_config, solo_config)
      assert VeChain.Configuration.get_network(:solo) == solo_config
      Application.delete_env(:vechain, :network_config)
    end

    test "returns application config when network is nil" do
      Application.put_env(:vechain, :network, :mainnet)
      assert VeChain.Configuration.get_network(nil) == %{chain_tag: <<0x4A>>}
    end

    test "defaults to mainnet when network is nil and no application config set" do
      Application.delete_env(:vechain, :network)
      assert VeChain.Configuration.get_network(nil) == %{chain_tag: <<0x4A>>}
    end

    test "raises ArgumentError for invalid network atom" do
      assert_raise ArgumentError, ~r/Invalid network: :invalid/, fn ->
        VeChain.Configuration.get_network(:invalid)
      end
    end

    test "raises ArgumentError for invalid network string" do
      assert_raise ArgumentError, ~r/Invalid network: "mainnet"/, fn ->
        VeChain.Configuration.get_network("mainnet")
      end
    end

    test "raises ArgumentError when custom config is not set in application environment" do
      Application.delete_env(:vechain, :network_config)

      assert_raise ArgumentError,
                   ~r/could not fetch application environment :network_config/,
                   fn ->
                     VeChain.Configuration.get_network(:custom)
                   end
    end

    test "raises ArgumentError when solo config is not set in application environment" do
      Application.delete_env(:vechain, :network_config)

      assert_raise ArgumentError,
                   ~r/could not fetch application environment :network_config/,
                   fn ->
                     VeChain.Configuration.get_network(:solo)
                   end
    end
  end

  describe "get_block_ref/2" do
    test "uses provided block_ref from opts" do
      config = %{}
      block_ref = <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08>>
      opts = [block_ref: block_ref]

      result = VeChain.Configuration.get_block_ref(config, opts)

      assert %{block_ref: ^block_ref} = result
    end

    test "accepts exactly 8-byte block_ref" do
      config = %{}
      block_ref = <<0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88>>
      opts = [block_ref: block_ref]

      result = VeChain.Configuration.get_block_ref(config, opts)

      assert %{block_ref: ^block_ref} = result
      assert byte_size(result.block_ref) == 8
    end

    test "accepts hex-encoded block_ref string" do
      config = %{}
      hex_block_ref = "0x0102030405060708"
      opts = [block_ref: hex_block_ref]

      result = VeChain.Configuration.get_block_ref(config, opts)

      assert %{block_ref: block_ref} = result
      assert block_ref == <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08>>
      assert byte_size(block_ref) == 8
    end

    test "accepts hex-encoded block_ref with uppercase letters" do
      config = %{}
      hex_block_ref = "0xFFEEDDCCBBAA9988"
      opts = [block_ref: hex_block_ref]

      result = VeChain.Configuration.get_block_ref(config, opts)

      assert %{block_ref: block_ref} = result
      assert block_ref == <<0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88>>
    end

    test "raises ArgumentError for block_ref with less than 8 bytes" do
      config = %{}
      opts = [block_ref: <<0x01, 0x02, 0x03>>]

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     VeChain.Configuration.get_block_ref(config, opts)
                   end
    end

    test "raises ArgumentError for hex block_ref with less than 8 bytes" do
      config = %{}
      opts = [block_ref: "0x010203"]

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     VeChain.Configuration.get_block_ref(config, opts)
                   end
    end

    test "raises ArgumentError for block_ref with more than 8 bytes" do
      config = %{}
      opts = [block_ref: <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09>>]

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     VeChain.Configuration.get_block_ref(config, opts)
                   end
    end

    test "raises ArgumentError for hex block_ref with more than 8 bytes" do
      config = %{}
      opts = [block_ref: "0x010203040506070809"]

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     VeChain.Configuration.get_block_ref(config, opts)
                   end
    end

    test "raises ArgumentError for empty block_ref" do
      config = %{}
      opts = [block_ref: <<>>]

      assert_raise ArgumentError,
                   "Block ref must be a binary string of 8 bytes (16 hex characters)",
                   fn ->
                     VeChain.Configuration.get_block_ref(config, opts)
                   end
    end

    test "preserves other config fields" do
      config = %{chain_tag: <<0x4A>>, nonce: <<1, 2, 3>>}
      block_ref = <<0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88>>
      opts = [block_ref: block_ref]

      result = VeChain.Configuration.get_block_ref(config, opts)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == <<1, 2, 3>>
      assert result.block_ref == block_ref
    end
  end

  describe "get_expiration/2" do
    test "uses provided expiration from opts" do
      config = %{}
      opts = [expiration: 100]

      result = VeChain.Configuration.get_expiration(config, opts)

      assert %{expiration: expiration} = result
      assert is_binary(expiration)
      assert expiration == :binary.encode_unsigned(100)
    end

    test "uses default expiration when not provided in opts" do
      config = %{}
      opts = []

      result = VeChain.Configuration.get_expiration(config, opts)

      assert %{expiration: expiration} = result
      assert is_binary(expiration)
      assert expiration == :binary.encode_unsigned(32)
    end

    test "uses application env default when configured" do
      Application.put_env(:vechain, :default_expiration, 64)
      config = %{}
      opts = []

      result = VeChain.Configuration.get_expiration(config, opts)

      assert %{expiration: expiration} = result
      assert expiration == :binary.encode_unsigned(64)
      Application.delete_env(:vechain, :default_expiration)
    end

    test "opts take precedence over application env" do
      Application.put_env(:vechain, :default_expiration, 64)
      config = %{}
      opts = [expiration: 50]

      result = VeChain.Configuration.get_expiration(config, opts)

      assert %{expiration: expiration} = result
      assert expiration == :binary.encode_unsigned(50)
      Application.delete_env(:vechain, :default_expiration)
    end

    test "accepts 1 as minimum valid expiration" do
      config = %{}
      opts = [expiration: 1]

      result = VeChain.Configuration.get_expiration(config, opts)

      assert %{expiration: expiration} = result
      assert expiration == :binary.encode_unsigned(1)
    end

    test "accepts maximum 4-byte expiration value" do
      config = %{}
      max_expiration = 0xFFFFFFFF
      opts = [expiration: max_expiration]

      result = VeChain.Configuration.get_expiration(config, opts)

      assert %{expiration: expiration} = result
      assert byte_size(expiration) == 4
    end

    test "converts integer expiration to binary" do
      config = %{}
      opts = [expiration: 255]

      result = VeChain.Configuration.get_expiration(config, opts)

      assert %{expiration: expiration} = result
      assert expiration == <<255>>
    end

    test "raises ArgumentError for zero expiration" do
      config = %{}
      opts = [expiration: 0]

      assert_raise ArgumentError, "Expiration must be a positive integer", fn ->
        VeChain.Configuration.get_expiration(config, opts)
      end
    end

    test "raises ArgumentError for negative expiration" do
      config = %{}
      opts = [expiration: -1]

      assert_raise ArgumentError, "Expiration must be a positive integer", fn ->
        VeChain.Configuration.get_expiration(config, opts)
      end
    end

    test "raises ArgumentError for expiration exceeding 4 bytes" do
      config = %{}
      opts = [expiration: 0x100000000]

      assert_raise ArgumentError,
                   "Expiration must be a positive integer of up to 4 bytes (< 2^32)",
                   fn ->
                     VeChain.Configuration.get_expiration(config, opts)
                   end
    end

    test "preserves other config fields" do
      config = %{chain_tag: <<0x4A>>, nonce: <<1, 2, 3>>}
      opts = [expiration: 50]

      result = VeChain.Configuration.get_expiration(config, opts)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == <<1, 2, 3>>
      assert result.expiration == :binary.encode_unsigned(50)
    end
  end

  # TODO: Add tests once implementation is finalized
  # describe "get_gas_fields/3" do
  # end

  describe "get_nonce/2" do
    test "uses provided nonce from opts" do
      config = %{}
      opts = [nonce: 12345]

      result = VeChain.Configuration.get_nonce(config, opts)

      assert %{nonce: nonce} = result
      assert is_binary(nonce)
      assert nonce == :binary.encode_unsigned(12345)
    end

    test "generates nonce when not provided in opts" do
      config = %{}
      opts = []

      result = VeChain.Configuration.get_nonce(config, opts)

      assert %{nonce: nonce} = result
      assert is_binary(nonce)
      assert byte_size(nonce) <= 8
    end

    test "accepts zero as a valid nonce" do
      config = %{}
      opts = [nonce: 0]

      result = VeChain.Configuration.get_nonce(config, opts)

      assert %{nonce: nonce} = result
      assert nonce == :binary.encode_unsigned(0)
    end

    test "accepts maximum 8-byte nonce value" do
      config = %{}
      max_nonce = 0xFFFFFFFFFFFFFFFF
      opts = [nonce: max_nonce]

      result = VeChain.Configuration.get_nonce(config, opts)

      assert %{nonce: nonce} = result
      assert byte_size(nonce) == 8
    end

    test "converts integer nonce to binary" do
      config = %{}
      opts = [nonce: 255]

      result = VeChain.Configuration.get_nonce(config, opts)

      assert %{nonce: nonce} = result
      assert nonce == <<255>>
    end

    test "raises ArgumentError for negative nonce" do
      config = %{}
      opts = [nonce: -1]

      assert_raise ArgumentError, "Nonce must be a non-negative integer", fn ->
        VeChain.Configuration.get_nonce(config, opts)
      end
    end

    test "raises ArgumentError for nonce exceeding 8 bytes" do
      config = %{}
      opts = [nonce: 0x10000000000000000]

      assert_raise ArgumentError,
                   "Nonce must be a non-negative integer of up to 8 bytes (< 2^64)",
                   fn ->
                     VeChain.Configuration.get_nonce(config, opts)
                   end
    end

    test "preserves other config fields" do
      config = %{chain_tag: <<0x4A>>, block_ref: <<1, 2, 3, 4, 5, 6, 7, 8>>}
      opts = [nonce: 100]

      result = VeChain.Configuration.get_nonce(config, opts)

      assert result.chain_tag == <<0x4A>>
      assert result.block_ref == <<1, 2, 3, 4, 5, 6, 7, 8>>
      assert result.nonce == :binary.encode_unsigned(100)
    end
  end
end
