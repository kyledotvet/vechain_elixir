defmodule VeChain.Transaction.Steps.Sign do
  @moduledoc """
  Pipeline step to sign a transaction.

  Signs the transaction with a private key using SECP256K1. The signature
  is 65 bytes (r + s + v format).

  For VIP-191 fee delegation, this produces the origin signature. The gas
  payer signature is added by the CoSign step.

  ## Examples

      iex> tx = Transaction.new(chain_tag: 0x27)
      iex> |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      iex> private_key = Secp256k1.generate_private_key()
      iex> tx = Sign.call(tx, private_key: private_key)
      iex> byte_size(tx.signature)
      65
  """

  alias VeChain.{Transaction, Crypto.Secp256k1}

  @doc """
  Signs the transaction with a private key.

  ## Parameters

    * `tx` - Transaction struct
    * `opts` - Options:
      - `:private_key` - 32-byte private key (required)

  ## Returns

  Signed transaction struct.

  ## Raises

  ArgumentError if private_key is not provided or invalid.
  """
  @spec call(Transaction.t(), keyword()) :: Transaction.t()
  def call(%Transaction{} = tx, opts) do
    private_key = Keyword.get(opts, :private_key)

    if private_key == nil do
      raise ArgumentError, "private_key option is required for signing"
    end

    unless is_binary(private_key) and byte_size(private_key) == 32 do
      raise ArgumentError, "private_key must be a 32-byte binary"
    end

    # Get signing hash
    signing_hash = Transaction.get_signing_hash(tx)

    # Sign with private key
    signature = Secp256k1.sign(signing_hash, private_key)

    # Emit telemetry event
    :telemetry.execute(
      [:vechain, :transaction, :sign],
      %{},
      %{transaction: tx}
    )

    %{tx | signature: signature}
  end
end
