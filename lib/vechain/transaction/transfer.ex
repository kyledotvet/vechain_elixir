defmodule VeChain.Transaction.Transfer do
  alias VeChain.Types
  alias VeChain.Utils

  defstruct [
    :sender,
    :recipient,
    :amount
  ]

  @type t :: %__MODULE__{
          sender: Types.t_address(),
          recipient: Types.t_address(),
          amount: non_neg_integer()
        }

  def cast_all([]), do: []

  def cast_all([transfer | rest]) do
    [cast(transfer) | cast_all(rest)]
  end

  def cast(%{
        "sender" => sender,
        "recipient" => recipient,
        "amount" => amount
      }) do
    %__MODULE__{
      # sender is required (20-byte address)
      sender: Utils.address_to_binary!(sender),
      # recipient is required (20-byte address)
      recipient: Utils.address_to_binary!(recipient),
      amount: amount
    }
  end

  defimpl Inspect do
    alias VeChain.Utils

    def inspect(tx_transfer, opts) do
      # Use the default struct inspection with the modified tx_transfer
      %{
        tx_transfer
        | sender: Utils.hex_encode(tx_transfer.sender),
          recipient: Utils.hex_encode(tx_transfer.recipient)
      }
      |> Inspect.Any.inspect(opts)
    end
  end
end
