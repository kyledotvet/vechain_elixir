defmodule VeChain.Transaction.Steps.CoSign do
  @moduledoc """
  Pipeline step for VIP-191 fee delegation co-signing.

  In VIP-191 fee delegation, two parties sign the transaction:
    1. **Origin**: Transaction sender (signs the transaction signing hash)
    2. **Gas Payer**: Fee sponsor (signs the transaction ID)

  The final signature is 130 bytes: origin_signature (65 bytes) + gas_payer_signature (65 bytes).

  **Important**: The gas payer signs a DIFFERENT hash than the origin:
    - Origin signs: Blake2b(unsigned_tx_rlp)
    - Gas payer signs: Blake2b(origin_signing_hash || origin_address) = transaction ID

  This step is only used when fee delegation is enabled via the Reserved field.

  ## Examples

      iex> tx = Transaction.new(chain_tag: 0x27)
      iex> |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      iex> |> Transaction.put_reserved(Reserved.enable_vip191())
      iex> |> Sign.call(private_key: origin_key)
      iex> tx = CoSign.call(tx, gas_payer_key: gas_payer_key)
      iex> byte_size(tx.signature)
      130
  """

  alias VeChain.{Transaction, Reserved, Crypto.Secp256k1}

  @doc """
  Co-signs the transaction with a gas payer's private key (VIP-191).

  Only applies if VIP-191 is enabled in the reserved field and a gas_payer_key
  is provided.

  ## Parameters

    * `tx` - Transaction struct (must already be signed by origin)
    * `opts` - Options:
      - `:gas_payer_key` - 32-byte gas payer private key (optional)

  ## Returns

  Transaction with gas payer signature appended (130 bytes total).

  ## Raises

  ArgumentError if transaction is not signed by origin or if VIP-191 is enabled
  but gas_payer_key is not provided.
  """
  @spec call(Transaction.t(), keyword()) :: Transaction.t()
  def call(%Transaction{signature: nil} = _tx, opts) do
    gas_payer_key = Keyword.get(opts, :gas_payer_key)

    if gas_payer_key != nil do
      raise ArgumentError, "Transaction must be signed by origin before co-signing"
    end

    # No gas payer key and no origin signature - just pass through
    raise ArgumentError, "Transaction must be signed before co-signing"
  end

  def call(%Transaction{reserved: reserved, signature: origin_sig} = tx, opts)
      when byte_size(origin_sig) == 65 do
    gas_payer_key = Keyword.get(opts, :gas_payer_key)

    # Check if VIP-191 is enabled
    if Reserved.fee_delegation_enabled?(reserved) do
      if gas_payer_key == nil do
        raise ArgumentError,
              "gas_payer_key is required when VIP-191 fee delegation is enabled"
      end

      unless is_binary(gas_payer_key) and byte_size(gas_payer_key) == 32 do
        raise ArgumentError, "gas_payer_key must be a 32-byte binary"
      end

      # Gas payer signs the transaction ID
      tx_id = get_transaction_id_for_gas_payer(tx)
      gas_payer_sig = Secp256k1.sign(tx_id, gas_payer_key)

      # Concatenate signatures: origin + gas_payer = 130 bytes
      combined_signature = origin_sig <> gas_payer_sig

      %{tx | signature: combined_signature}
    else
      # VIP-191 not enabled - just pass through
      tx
    end
  end

  def call(%Transaction{signature: sig} = tx, _opts) when byte_size(sig) == 130 do
    # Already co-signed - pass through
    tx
  end

  def call(%Transaction{} = tx, _opts) do
    # Other cases - pass through
    tx
  end

  # ========================================
  # Private Helpers
  # ========================================

  # Calculate the transaction ID that the gas payer needs to sign
  # This is Blake2b(signing_hash || origin_address)
  defp get_transaction_id_for_gas_payer(%Transaction{signature: origin_sig} = tx) do
    # Get the signing hash (what origin signed)
    signing_hash = Transaction.get_signing_hash(tx)

    # Recover origin address from signature
    {:ok, origin_address} = Secp256k1.recover_address(signing_hash, origin_sig)

    # Transaction ID = Blake2b(signing_hash || origin_address)
    VeChain.Crypto.Blake2b.hash(signing_hash <> origin_address)
  end
end
