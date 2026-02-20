defmodule VeChain.Transaction.Validation do
  @moduledoc """
  Validation functions for transaction fields.
  """
  alias VeChain.Utils

  def block_ref(%{block_ref: "0x" <> _hex = block_ref} = config)
      when is_binary(block_ref) do
    block_ref(%{config | block_ref: Utils.hex_decode!(block_ref)})
  end

  def block_ref(%{block_ref: block_ref} = config)
      when is_binary(block_ref) and byte_size(block_ref) == 8 do
    config
  end

  def block_ref(_config) do
    raise ArgumentError, "Block ref must be a binary string of 8 bytes (16 hex characters)"
  end

  def expiration(%{expiration: expiration} = config)
      when is_integer(expiration) and expiration > 0 do
    %{
      config
      | expiration: validate_binary_expiration(:binary.encode_unsigned(expiration))
    }
  end

  def expiration(_config) do
    raise ArgumentError, "Expiration must be a positive integer"
  end

  defp validate_binary_expiration(expiration)
       when is_binary(expiration) and byte_size(expiration) <= 4 do
    expiration
  end

  defp validate_binary_expiration(_expiration) do
    raise ArgumentError, "Expiration must be a positive integer of up to 4 bytes (< 2^32)"
  end

  def gas_fields(config, :eip_1559) do
    config
    |> validate_eip_1559_field(:max_priority_fee_per_gas)
    |> validate_eip_1559_field(:max_fee_per_gas)
  end

  def gas_fields(config, :legacy) do
    config
    |> validate_binary_gas_price_coef()
  end

  defp validate_eip_1559_field(config, field) do
    config
    |> Map.get(field)
    |> case do
      value when is_integer(value) and value >= 0 ->
        Map.put(
          config,
          field,
          value
          |> :binary.encode_unsigned()
          |> validate_binary_eip_1559_gas_field(field)
        )

      _ ->
        raise ArgumentError, "#{field} must be a non-negative integer of up to 32 bytes (< 2^256)"
    end
  end

  defp validate_binary_eip_1559_gas_field(gas_field, _field)
       when is_binary(gas_field) and byte_size(gas_field) <= 32 do
    gas_field
  end

  defp validate_binary_eip_1559_gas_field(_gas_field, field) do
    raise ArgumentError, "#{field} must be a non-negative integer of up to 32 bytes (< 2^256)"
  end

  defp validate_binary_gas_price_coef(%{gas_price_coef: gas_price_coef} = config)
       when is_integer(gas_price_coef) and gas_price_coef >= 0 and gas_price_coef <= 255 do
    %{config | gas_price_coef: :binary.encode_unsigned(gas_price_coef)}
  end

  def nonce(%{nonce: nonce} = config) when is_integer(nonce) and nonce >= 0 do
    %{config | nonce: validate_binary_nonce(:binary.encode_unsigned(nonce))}
  end

  def nonce(_config) do
    raise ArgumentError, "Nonce must be a non-negative integer of up to 8 bytes (< 2^64)"
  end

  defp validate_binary_nonce(nonce) when is_binary(nonce) and byte_size(nonce) <= 8 do
    nonce
  end

  defp validate_binary_nonce(_nonce) do
    raise ArgumentError, "Nonce must be a non-negative integer of up to 8 bytes (< 2^64)"
  end

  def depends_on(%{depends_on: nil} = config) do
    %{config | depends_on: <<>>}
  end

  def depends_on(%{depends_on: "0x" <> _hex = depends_on} = config)
      when is_binary(depends_on) do
    depends_on(%{config | depends_on: Utils.hex_decode!(depends_on)})
  end

  def depends_on(%{depends_on: depends_on} = config)
      when is_binary(depends_on) and byte_size(depends_on) == 32 do
    config
  end

  def depends_on(_config) do
    raise ArgumentError,
          "depends_on must be nil or a binary string of 32 bytes (64 hex characters) representing a transaction ID"
  end
end
