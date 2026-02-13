defmodule VeChain.Transaction.Eip1559 do
  @moduledoc """
  Module representing EIP-1559 (Dynamic Gas Fee) transactions on the VeChain blockchain.

  This struct and its associated functions handle the specific fields and encoding logic for EIP-1559 transactions, which include dynamic fee fields like `max_priority_fee_per_gas` and `max_fee_per_gas`. The module also implements the necessary protocols for RLP encoding and inspection.

  Most users will interact with this module indirectly through `VeChain.Transaction`, which will determine the appropriate behavior based on the struct and configuration.
  """
  alias VeChain.Transaction.Clause
  alias VeChain.Transaction.Reserved
  alias VeChain.Transaction.Signature
  alias VeChain.Transaction
  alias VeChain.Utils

  defstruct [
    :id,
    :chain_tag,
    :block_ref,
    :expiration,
    :max_priority_fee_per_gas,
    :max_fee_per_gas,
    :gas,
    :depends_on,
    :nonce,
    :signature,
    :origin,
    :delegator,
    clauses: [],
    reserved: %Reserved{}
  ]

  @type t() :: %__MODULE__{
          id: Transaction.id(),
          chain_tag: Transaction.chain_tag(),
          block_ref: Transaction.block_ref(),
          expiration: Transaction.expiration(),
          max_priority_fee_per_gas: binary(),
          max_fee_per_gas: binary(),
          gas: Transaction.gas(),
          depends_on: Transaction.depends_on(),
          nonce: Transaction.nonce(),
          signature: Transaction.signature(),
          origin: Transaction.origin(),
          delegator: Transaction.delegator(),
          clauses: Transaction.clauses(),
          reserved: Reserved.t()
        }

  @doc """
  Creates a new EIP-1559 transaction struct based on passed in attributes. The expectation is that the attributes are coming from `VeChain.Transaction.new/1` and have already been validated and transformed into the correct format (binary). Odds are good that if you are calling this function directly, you may be doing something wrong.

  Raises if unsupported fields are provided.
  """
  def new(%{gas_price_coef: _anything}),
    do: raise(ArgumentError, "EIP-1559 transactions do not use gas_price_coef")

  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Casts a RLP decoded list into an EIP-1559 transaction struct.
  This is used internally when decoding raw transactions from the blockchain.

  Ref: `VeChain.Transaction.typed_cast/1`
  """
  def cast([
        chain_tag,
        block_ref,
        expiration,
        clauses,
        max_priority_fee_per_gas,
        max_fee_per_gas,
        gas,
        depends_on,
        nonce,
        reserved | signature
      ]) do
    %__MODULE__{
      chain_tag: chain_tag,
      block_ref: Utils.decompress_block_ref(block_ref),
      expiration: expiration,
      clauses: Enum.map(clauses, &Clause.cast/1),
      max_priority_fee_per_gas: max_priority_fee_per_gas,
      max_fee_per_gas: max_fee_per_gas,
      gas: gas,
      depends_on: depends_on,
      nonce: nonce,
      reserved: Reserved.cast(reserved),
      signature: List.first(signature)
    }
    |> Signature.maybe_parse()
  end

  @doc """
  Converts an EIP-1559 transaction struct into a list format suitable for RLP encoding. This is used internally when encoding transactions to be sent to the blockchain.

  Everything is stored in the struct as binary so we can just return the fields with minimal processing in the correct order for RLP encoding
  """
  @spec to_rlp_list(t()) :: list()
  def to_rlp_list(tx) do
    [
      tx.chain_tag,
      Utils.remove_leading_zeros(tx.block_ref),
      tx.expiration,
      tx.clauses,
      tx.max_priority_fee_per_gas,
      tx.max_fee_per_gas,
      tx.gas,
      tx.depends_on,
      tx.nonce,
      tx.reserved
    ]
  end

  defimpl ExRLP.Encode do
    alias VeChain.Transaction.Eip1559
    alias VeChain.Transaction.Signature

    def encode(eip1559_tx, options \\ []) do
      include_signature = Keyword.get(options, :include_signature, false)

      eip1559_tx
      |> Eip1559.to_rlp_list()
      |> Signature.maybe_include_signature(eip1559_tx, include_signature)
      |> ExRLP.encode(options)
      |> prepend_type_prefix()
    end

    defp prepend_type_prefix(rlp_encoded_tx) do
      <<0x51, rlp_encoded_tx::binary>>
    end
  end

  defimpl Inspect do
    alias VeChain.Utils

    def inspect(transaction, opts) do
      # Use the default struct inspection with the prepared fields
      %{
        transaction
        | id: Utils.hex_encode(transaction.id),
          chain_tag: :binary.decode_unsigned(transaction.chain_tag),
          block_ref: Utils.hex_encode(transaction.block_ref),
          expiration: :binary.decode_unsigned(transaction.expiration),
          max_priority_fee_per_gas: Utils.hex_encode(transaction.max_priority_fee_per_gas),
          max_fee_per_gas:
            Utils.hex_encode(transaction.max_fee_per_gas) |> Utils.drop_leading_zeros(),
          gas: :binary.decode_unsigned(transaction.gas),
          nonce: Utils.hex_encode(transaction.nonce),
          depends_on: Utils.nullable_hex_encode(transaction.depends_on),
          origin: Utils.hex_encode(transaction.origin),
          delegator: Utils.hex_encode(transaction.delegator)
      }
      |> Inspect.Any.inspect(opts)
    end
  end
end
