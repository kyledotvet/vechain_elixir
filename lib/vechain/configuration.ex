defmodule VeChain.Configuration do
  @moduledoc """
  This module provides functions to manage and validate configuration settings across the VeChain SDK.
  """
  alias VeChain.Utils
  alias VeChain.Client.Thor
  alias VeChain.Block

  def get_thor_node_url do
    Application.get_env(:vechain, :thor_node_url, "https://sync-mainnet.vechain.org/")
  end

  @spec get_network(atom() | nil) :: map()
  def get_network(nil) do
    Application.get_env(:vechain, :network, :mainnet)
    |> get_network()
  end

  def get_network(:mainnet), do: %{chain_tag: <<0x4A>>}
  def get_network(:testnet), do: %{chain_tag: <<0x27>>}
  def get_network(:custom), do: Application.fetch_env!(:vechain, :network_config)
  def get_network(:solo), do: Application.fetch_env!(:vechain, :network_config)

  def get_network(other) do
    raise ArgumentError,
          "Invalid network: #{inspect(other)}. Valid options are :mainnet, :testnet, :solo, or :custom (with custom config provided in application environment in the form of %{chain_tag: <<0xXX>>})"
  end

  @spec get_block_ref(map(), keyword()) :: %{:block_ref => binary(), optional(any()) => any()}
  def get_block_ref(config, opts) do
    config
    |> Map.put(
      :block_ref,
      Keyword.get_lazy(opts, :block_ref, &new_best_block_ref/0)
    )
  end

  defp new_best_block_ref do
    Application.get_env(:vechain, :thor_node_url, "https://sync-mainnet.vechain.org/")
    |> Thor.new()
    |> Thor.get_block!("best")
    |> Block.get_ref()
  end

  def get_expiration(config, opts) do
    config
    |> Map.put(
      :expiration,
      Keyword.get(opts, :expiration, Application.get_env(:vechain, :default_expiration, 32))
    )
  end

  def get_gas_fields(config, :eip_1559, opts) do
    config
    |> Map.put(
      :max_priority_fee_per_gas,
      Keyword.get_lazy(opts, :max_priority_fee_per_gas, fn ->
        Application.get_env(:vechain, :default_max_priority_fee_per_gas, 500)
      end)
    )
    |> Map.put(
      :max_fee_per_gas,
      Keyword.get_lazy(opts, :max_fee_per_gas, fn ->
        Application.get_env(:vechain, :default_max_fee_per_gas, 1_000_000)
      end)
    )
  end

  def get_gas_fields(config, :legacy, opts) do
    config
    |> Map.put(
      :gas_price_coef,
      Keyword.get_lazy(opts, :gas_price_coef, fn ->
        Application.get_env(:vechain, :default_gas_price_coef, 128)
      end)
    )
  end

  def get_gas_fields(_config, transaction_type, _opts) do
    raise ArgumentError, "Unsupported transaction type: #{inspect(transaction_type)}"
  end

  @spec get_nonce(map(), keyword()) :: %{:nonce => any(), optional(any()) => any()}
  def get_nonce(config, opts) do
    Map.put(config, :nonce, Keyword.get(opts, :nonce, Utils.generate_nonce()))
  end

  def get_private_key(config, key_type, opts) do
    config
    |> Map.put(
      :private_key,
      Keyword.get_lazy(opts, :private_key, fn ->
        Application.fetch_env!(:vechain, key_type)
      end)
    )
  end
end
