defmodule VeChain.Transaction.Steps.SetExpiration do
  @moduledoc """
  Pipeline step to set the expiration on a transaction.

  The expiration field specifies how many blocks after the block reference
  the transaction remains valid. After this window, the transaction can no
  longer be included in a block.

  Default expiration is 32 blocks (approximately 5 minutes with 10-second blocks).

  ## Examples

      iex> tx = Transaction.new()
      iex> tx = SetExpiration.call(tx)
      iex> tx.expiration
      32
  """

  alias VeChain.Transaction

  @default_expiration 32

  @doc """
  Sets the expiration if not already present.

  Uses the expiration already set on the transaction, or defaults to 32 blocks.

  ## Parameters

    * `tx` - Transaction struct
    * `opts` - Options:
      - `:expiration` - Override expiration value (optional)

  ## Returns

  Transaction with expiration set.
  """
  @spec call(Transaction.t(), keyword()) :: Transaction.t()
  def call(%Transaction{expiration: expiration} = tx, opts) when expiration != nil and expiration > 0 do
    # Expiration already set and valid - don't override unless opts specify
    case Keyword.get(opts, :expiration) do
      nil -> tx
      override_exp -> %{tx | expiration: override_exp}
    end
  end

  def call(%Transaction{} = tx, opts) do
    # No expiration or zero - set to default or override
    expiration = Keyword.get(opts, :expiration, @default_expiration)
    %{tx | expiration: expiration}
  end
end
