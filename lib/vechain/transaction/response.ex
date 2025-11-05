defmodule VeChain.Transaction.Response do
  alias VeChain.Clause
  alias VeChain.Types
  alias VeChain.Utils
  alias VeChain.Transaction.Meta

  defstruct [
    # The first 8 bytes of a referenced block ID.
    :block_ref,
    :chain_tag,
    :clauses,
    :delegator,
    :depends_on,
    :expiration,
    :gas,
    :gas_price_coef,
    :max_fee_per_gas,
    :max_priority_fee_per_gas,
    :id,
    :meta,
    :nonce,
    :origin,
    :size,
    :type
  ]

  @type t :: %__MODULE__{
          block_ref: Types.t_block_ref(),
          chain_tag: non_neg_integer(),
          clauses: [Clause.t()],
          delegator: Types.t_address() | nil,
          depends_on: Types.t_hash() | nil,
          expiration: non_neg_integer(),
          gas: non_neg_integer(),
          gas_price_coef: non_neg_integer() | nil,
          max_fee_per_gas: binary() | nil,
          max_priority_fee_per_gas: binary() | nil,
          id: Types.t_hash(),
          meta: Meta.t(),
          nonce: binary(),
          origin: Types.t_address(),
          size: non_neg_integer(),
          type: Types.tx_type()
        }

  def cast(%{
        "blockRef" => block_ref,
        "chainTag" => chain_tag,
        "clauses" => clauses,
        "delegator" => delegator,
        "dependsOn" => depends_on,
        "expiration" => expiration,
        "gas" => gas,
        "gasPriceCoef" => gas_price_coef,
        "id" => id,
        "meta" => meta,
        "nonce" => nonce,
        "origin" => origin,
        "size" => tx_size,
        "type" => 0
      }) do
    %__MODULE__{
      block_ref: Utils.hex_decode!(block_ref),
      chain_tag: chain_tag,
      clauses: Clause.cast_all(clauses),
      # delegator is nullable (used in fee delegation)
      delegator: Utils.maybe_address_to_binary(delegator),
      # depends_on is nullable (used for transaction dependencies)
      depends_on: Utils.maybe_hex_decode(depends_on),
      expiration: expiration,
      gas: gas,
      gas_price_coef: gas_price_coef,
      # id is required (transaction hash)
      id: Utils.hex_decode!(id),
      meta: Meta.cast(meta),
      nonce: Utils.hex_decode!(nonce),
      # origin is required (sender address)
      origin: Utils.address_to_binary!(origin),
      size: tx_size,
      type: 0
    }
  end

  def cast(%{
        "blockRef" => block_ref,
        "chainTag" => chain_tag,
        "clauses" => clauses,
        "delegator" => delegator,
        "dependsOn" => depends_on,
        "expiration" => expiration,
        "gas" => gas,
        "maxFeePerGas" => max_fee_per_gas,
        "maxPriorityFeePerGas" => max_priority_fee_per_gas,
        "id" => id,
        "meta" => meta,
        "nonce" => nonce,
        "origin" => origin,
        "size" => tx_size,
        "type" => 81
      }) do
    %__MODULE__{
      block_ref: Utils.hex_decode!(block_ref),
      chain_tag: chain_tag,
      clauses: Clause.cast_all(clauses),
      # delegator is nullable (used in fee delegation)
      delegator: Utils.maybe_address_to_binary(delegator),
      # depends_on is nullable (used for transaction dependencies)
      depends_on: Utils.maybe_hex_decode(depends_on),
      expiration: expiration,
      gas: gas,
      max_fee_per_gas: Utils.hex_decode!(max_fee_per_gas),
      max_priority_fee_per_gas: Utils.hex_decode!(max_priority_fee_per_gas),
      # id is required (transaction hash)
      id: Utils.hex_decode!(id),
      meta: Meta.cast(meta),
      nonce: Utils.hex_decode!(nonce),
      # origin is required (sender address)
      origin: Utils.address_to_binary!(origin),
      size: tx_size,
      type: 81
    }
  end

  defimpl Inspect do
    alias VeChain.Utils

    def inspect(%{type: 0} = tx_response, opts) do
      # Use the default struct inspection with the modified tx_response
      %{
        tx_response
        | block_ref: Utils.hex_encode(tx_response.block_ref),
          delegator: Utils.hex_encode(tx_response.delegator),
          depends_on: Utils.hex_encode(tx_response.depends_on),
          id: Utils.hex_encode(tx_response.id),
          origin: Utils.hex_encode(tx_response.origin),
          nonce: Utils.hex_encode(tx_response.nonce),
          type: Utils.type_to_atom(tx_response.type)
      }
      |> Inspect.Any.inspect(opts)
    end

    def inspect(%{type: 81} = tx_response, opts) do
      # Use the default struct inspection with the modified tx_response
      %{
        tx_response
        | block_ref: Utils.hex_encode(tx_response.block_ref),
          delegator: Utils.hex_encode(tx_response.delegator),
          depends_on: Utils.hex_encode(tx_response.depends_on),
          id: Utils.hex_encode(tx_response.id),
          max_fee_per_gas: Utils.hex_encode(tx_response.max_fee_per_gas),
          max_priority_fee_per_gas: Utils.hex_encode(tx_response.max_priority_fee_per_gas),
          origin: Utils.hex_encode(tx_response.origin),
          nonce: Utils.hex_encode(tx_response.nonce),
          type: Utils.type_to_atom(tx_response.type)
      }
      |> Inspect.Any.inspect(opts)
    end
  end
end
