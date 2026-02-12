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
    Map.put(config, :block_ref, Keyword.get_lazy(opts, :block_ref, &new_best_block_ref/0))
    |> validate_block_ref()
  end

  defp new_best_block_ref do
    Application.get_env(:vechain, :thor_node_url, "https://sync-mainnet.vechain.org/")
    |> Thor.new()
    |> Thor.get_block!("best")
    |> Block.get_ref()
  end

  defp validate_block_ref(%{block_ref: "0x" <> _hex = block_ref} = config)
       when is_binary(block_ref) do
    validate_block_ref(%{config | block_ref: Utils.hex_decode!(block_ref)})
  end

  defp validate_block_ref(%{block_ref: block_ref} = config)
       when is_binary(block_ref) and byte_size(block_ref) == 8 do
    config
  end

  defp validate_block_ref(_config) do
    raise ArgumentError, "Block ref must be a binary string of 8 bytes (16 hex characters)"
  end

  def get_expiration(config, opts) do
    config
    |> Map.put(
      :expiration,
      Keyword.get(opts, :expiration, Application.get_env(:vechain, :default_expiration, 32))
    )
    |> validate_expiration()
  end

  defp validate_expiration(%{expiration: expiration} = config)
       when is_integer(expiration) and expiration > 0 do
    %{
      config
      | expiration: validate_binary_expiration(:binary.encode_unsigned(expiration))
    }
  end

  defp validate_expiration(_config) do
    raise ArgumentError, "Expiration must be a positive integer"
  end

  defp validate_binary_expiration(expiration)
       when is_binary(expiration) and byte_size(expiration) <= 4 do
    expiration
  end

  defp validate_binary_expiration(_expiration) do
    raise ArgumentError, "Expiration must be a positive integer of up to 4 bytes (< 2^32)"
  end

  def get_gas_fields(config, :eip_1559, opts) do
    config
    |> Map.put(
      :max_priority_fee_per_gas,
      Keyword.get_lazy(opts, :max_priority_fee_per_gas, fn ->
        Application.get_env(:vechain, :default_max_priority_fee_per_gas, 400_000)
      end)
    )
    |> Map.put(
      :max_fee_per_gas,
      Keyword.get_lazy(opts, :max_fee_per_gas, fn ->
        Application.get_env(:vechain, :default_max_fee_per_gas, 400_000)
      end)
    )
  end

  def get_gas_fields(config, :legacy, opts) do
    config
    |> Map.put(
      :gas_price_coef,
      Keyword.get_lazy(opts, :gas_price_coef, fn ->
        Application.get_env(:vechain, :default_gas_price_coef, 0)
      end)
    )
  end

  def get_gas_fields(_config, transaction_type, _opts) do
    raise ArgumentError, "Unsupported transaction type: #{inspect(transaction_type)}"
  end

  @spec get_nonce(map(), keyword()) :: %{:nonce => any(), optional(any()) => any()}
  def get_nonce(config, opts) do
    Map.put(config, :nonce, Keyword.get(opts, :nonce, Utils.generate_nonce()))
    |> validate_nonce()
  end

  defp validate_nonce(%{nonce: nonce} = config) when is_integer(nonce) and nonce >= 0 do
    %{config | nonce: validate_binary_nonce(:binary.encode_unsigned(nonce))}
  end

  defp validate_nonce(_config) do
    raise ArgumentError, "Nonce must be a non-negative integer"
  end

  defp validate_binary_nonce(nonce) when is_binary(nonce) and byte_size(nonce) <= 8 do
    nonce
  end

  defp validate_binary_nonce(_nonce) do
    raise ArgumentError, "Nonce must be a non-negative integer of up to 8 bytes (< 2^64)"
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
