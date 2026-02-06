defmodule VeChain.Transaction.Legacy do
  alias VeChain.Transaction.Reserved
  alias VeChain.Transaction.Clause
  alias VeChain.Transaction.Signature
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

  def new(%{max_fee_per_gas: _anything}),
    do: raise(ArgumentError, "Legacy transactions do not use max_fee_per_gas")

  def new(%{max_priority_fee_per_gas: _anything}),
    do: raise(ArgumentError, "Legacy transactions do not use max_priority_fee_per_gas")

  def new(attrs) do
    # TODO: Migrate this to validate attrs and convert to binary
    struct(__MODULE__, attrs)
  end

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
      # Use the default struct inspection with the prepared fields
      %{
        transaction
        | chain_tag: :binary.decode_unsigned(transaction.chain_tag),
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
