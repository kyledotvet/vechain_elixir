defmodule VeChain.Transaction.Legacy do
  @moduledoc """
  Module representing Legacy transactions on the VeChain blockchain.

  This struct and its associated functions handle the specific fields and encoding logic for Legacy transactions, which include the `gas_price_coef` field. The module also implements the necessary protocols for RLP encoding and inspection.

  Most users will interact with this module indirectly through `VeChain.Transaction`, which will determine the appropriate behavior based on the struct and configuration.
  """
  alias VeChain.Transaction.Reserved
  alias VeChain.Transaction.Clause
  alias VeChain.Transaction.Signature
  alias VeChain.Transaction
  alias VeChain.Utils

  defstruct [
    :id,
    :chain_tag,
    :block_ref,
    :expiration,
    :gas_price_coef,
    :gas,
    :depends_on,
    :nonce,
    :signature,
    :origin,
    :delegator,
    clauses: [],
    reserved: %Reserved{}
  ]

  @type gas_price_coef() :: binary()

  @type t() :: %__MODULE__{
          id: Transaction.id(),
          chain_tag: Transaction.chain_tag(),
          block_ref: Transaction.block_ref(),
          expiration: Transaction.expiration(),
          gas_price_coef: gas_price_coef(),
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
  Creates a new Legacy transaction struct based on passed in attributes . The expectation is that the attributes are coming from `VeChain.Transaction.new/1` and have already been validated and transformed into the correct format (binary). Odds are good that if you are calling this function directly, you may be doing something wrong.

  Raises if unsupported fields are provided.
  """
  def new(%{max_fee_per_gas: _anything}),
    do: raise(ArgumentError, "Legacy transactions do not use max_fee_per_gas")

  def new(%{max_priority_fee_per_gas: _anything}),
    do: raise(ArgumentError, "Legacy transactions do not use max_priority_fee_per_gas")

  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Casts a RLP decoded list into a Legacy transaction struct.
  This is used internally when decoding raw transactions from the blockchain.

  Ref: `VeChain.Transaction.typed_cast/1`
  """
  def cast([
        chain_tag,
        block_ref,
        expiration,
        clauses,
        gas_price_coef,
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
      gas_price_coef: gas_price_coef,
      gas: gas,
      depends_on: depends_on,
      nonce: nonce,
      reserved: Reserved.cast(reserved),
      signature: List.first(signature)
    }
    |> Signature.maybe_parse()
  end

  @doc """
  Converts a Legacy transaction struct into a list format suitable for RLP encoding. This is used internally when encoding transactions to be sent to the blockchain.
  """
  @spec to_rlp_list(t()) :: list()
  def to_rlp_list(tx) do
    # Everything is "stored" in the struct as binary so we can just
    # return the fields in the correct order for RLP encoding
    [
      tx.chain_tag,
      Utils.remove_leading_zeros(tx.block_ref),
      tx.expiration,
      tx.clauses,
      tx.gas_price_coef,
      tx.gas,
      tx.depends_on,
      tx.nonce,
      tx.reserved
    ]
  end

  defimpl ExRLP.Encode do
    alias VeChain.Transaction.Legacy
    alias VeChain.Transaction.Signature

    def encode(legacy_tx, options \\ []) do
      include_signature = Keyword.get(options, :include_signature, false)

      legacy_tx
      |> Legacy.to_rlp_list()
      |> Signature.maybe_include_signature(legacy_tx, include_signature)
      |> ExRLP.encode(options)
    end
  end

  defimpl Inspect do
    alias VeChain.Utils

    def inspect(transaction, opts) do
      %{
        transaction
        | id: Utils.hex_encode(transaction.id),
          chain_tag: :binary.decode_unsigned(transaction.chain_tag),
          block_ref: Utils.hex_encode(transaction.block_ref),
          expiration: :binary.decode_unsigned(transaction.expiration),
          gas_price_coef: :binary.decode_unsigned(transaction.gas_price_coef),
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
