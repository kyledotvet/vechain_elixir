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

      assert %{expiration: 100} = result
    end

    test "uses default expiration when not provided in opts" do
      config = %{}
      opts = []

      result = VeChain.Configuration.get_expiration(config, opts)

      assert %{expiration: 32} = result
    end

    test "uses application env default when configured" do
      Application.put_env(:vechain, :default_expiration, 64)
      config = %{}
      opts = []

      result = VeChain.Configuration.get_expiration(config, opts)

      assert %{expiration: 64} = result
      Application.delete_env(:vechain, :default_expiration)
    end

    test "opts take precedence over application env" do
      Application.put_env(:vechain, :default_expiration, 64)
      config = %{}
      opts = [expiration: 50]

      result = VeChain.Configuration.get_expiration(config, opts)

      assert %{expiration: 50} = result
      Application.delete_env(:vechain, :default_expiration)
    end

    test "preserves other config fields" do
      config = %{chain_tag: <<0x4A>>, nonce: <<1, 2, 3>>}
      opts = [expiration: 50]

      result = VeChain.Configuration.get_expiration(config, opts)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == <<1, 2, 3>>
      assert result.expiration == 50
    end
  end

  describe "get_gas_fields/3 with :eip_1559" do
    test "uses provided gas fields from opts" do
      config = %{}
      opts = [max_priority_fee_per_gas: 1000, max_fee_per_gas: 2000]

      result = VeChain.Configuration.get_gas_fields(config, :eip_1559, opts)

      assert %{max_priority_fee_per_gas: 1000, max_fee_per_gas: 2000} = result
    end

    test "uses default gas fields when not provided in opts" do
      config = %{}
      opts = []

      result = VeChain.Configuration.get_gas_fields(config, :eip_1559, opts)

      assert %{max_priority_fee_per_gas: 500, max_fee_per_gas: 1_000_000} = result
    end

    test "uses application env defaults when configured" do
      Application.put_env(:vechain, :default_max_priority_fee_per_gas, 750)
      Application.put_env(:vechain, :default_max_fee_per_gas, 2_000_000)
      config = %{}
      opts = []

      result = VeChain.Configuration.get_gas_fields(config, :eip_1559, opts)

      assert %{max_priority_fee_per_gas: 750, max_fee_per_gas: 2_000_000} = result
      Application.delete_env(:vechain, :default_max_priority_fee_per_gas)
      Application.delete_env(:vechain, :default_max_fee_per_gas)
    end

    test "opts take precedence over application env" do
      Application.put_env(:vechain, :default_max_priority_fee_per_gas, 750)
      Application.put_env(:vechain, :default_max_fee_per_gas, 2_000_000)
      config = %{}
      opts = [max_priority_fee_per_gas: 1000, max_fee_per_gas: 3000]

      result = VeChain.Configuration.get_gas_fields(config, :eip_1559, opts)

      assert %{max_priority_fee_per_gas: 1000, max_fee_per_gas: 3000} = result
      Application.delete_env(:vechain, :default_max_priority_fee_per_gas)
      Application.delete_env(:vechain, :default_max_fee_per_gas)
    end

    test "preserves other config fields" do
      config = %{chain_tag: <<0x4A>>, nonce: 100}
      opts = [max_priority_fee_per_gas: 1000, max_fee_per_gas: 2000]

      result = VeChain.Configuration.get_gas_fields(config, :eip_1559, opts)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == 100
      assert result.max_priority_fee_per_gas == 1000
      assert result.max_fee_per_gas == 2000
    end
  end

  describe "get_gas_fields/3 with :legacy" do
    test "uses provided gas_price_coef from opts" do
      config = %{}
      opts = [gas_price_coef: 128]

      result = VeChain.Configuration.get_gas_fields(config, :legacy, opts)

      assert %{gas_price_coef: 128} = result
    end

    test "uses default gas_price_coef when not provided in opts" do
      config = %{}
      opts = []

      result = VeChain.Configuration.get_gas_fields(config, :legacy, opts)

      assert %{gas_price_coef: 128} = result
    end

    test "uses application env default when configured" do
      Application.put_env(:vechain, :default_gas_price_coef, 200)
      config = %{}
      opts = []

      result = VeChain.Configuration.get_gas_fields(config, :legacy, opts)

      assert %{gas_price_coef: 200} = result
      Application.delete_env(:vechain, :default_gas_price_coef)
    end

    test "opts take precedence over application env" do
      Application.put_env(:vechain, :default_gas_price_coef, 200)
      config = %{}
      opts = [gas_price_coef: 150]

      result = VeChain.Configuration.get_gas_fields(config, :legacy, opts)

      assert %{gas_price_coef: 150} = result
      Application.delete_env(:vechain, :default_gas_price_coef)
    end

    test "preserves other config fields" do
      config = %{chain_tag: <<0x4A>>, nonce: 100}
      opts = [gas_price_coef: 128]

      result = VeChain.Configuration.get_gas_fields(config, :legacy, opts)

      assert result.chain_tag == <<0x4A>>
      assert result.nonce == 100
      assert result.gas_price_coef == 128
    end
  end

  describe "get_gas_fields/3 with invalid type" do
    test "raises ArgumentError for unsupported transaction type" do
      config = %{}
      opts = []

      assert_raise ArgumentError, "Unsupported transaction type: :invalid", fn ->
        VeChain.Configuration.get_gas_fields(config, :invalid, opts)
      end
    end
  end

  describe "get_nonce/2" do
    test "uses provided nonce from opts" do
      config = %{}
      opts = [nonce: 12345]

      result = VeChain.Configuration.get_nonce(config, opts)

      assert %{nonce: 12345} = result
    end

    test "generates nonce when not provided in opts" do
      config = %{}
      opts = []

      result = VeChain.Configuration.get_nonce(config, opts)

      assert %{nonce: nonce} = result
      assert is_integer(nonce)
      assert nonce >= 0
    end

    test "preserves other config fields" do
      config = %{chain_tag: <<0x4A>>, block_ref: <<1, 2, 3, 4, 5, 6, 7, 8>>}
      opts = [nonce: 100]

      result = VeChain.Configuration.get_nonce(config, opts)

      assert result.chain_tag == <<0x4A>>
      assert result.block_ref == <<1, 2, 3, 4, 5, 6, 7, 8>>
      assert result.nonce == 100
    end
  end
end
