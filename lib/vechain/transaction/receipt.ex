defmodule VeChain.Transaction.Receipt do
  alias VeChain.Types
  alias VeChain.Utils
  alias VeChain.Transaction.Receipt.Meta
  alias VeChain.Transaction.Output

  defstruct [
    :gas_payer,
    :gas_used,
    :meta,
    :outputs,
    # The amount of energy (VTHO) in wei, used to pay for the gas
    :paid,
    :reverted,
    # The amount of energy (VTHO) in wei, paid to the block signer as a reward
    :reward
  ]

  @type t :: %__MODULE__{
          gas_payer: Types.t_address(),
          gas_used: non_neg_integer(),
          meta: VeChain.Transaction.Receipt.Meta.t(),
          outputs: [VeChain.Transaction.Output.t()],
          paid: binary(),
          reverted: boolean(),
          reward: binary()
        }

  def cast(%{
        "gasPayer" => gas_payer,
        "gasUsed" => gas_used,
        "meta" => meta,
        "outputs" => outputs,
        "paid" => paid,
        "reverted" => reverted,
        "reward" => reward
      }) do
    %__MODULE__{
      # gas_payer is required (address that paid for gas)
      gas_payer: Utils.address_to_binary!(gas_payer),
      gas_used: gas_used,
      meta: Meta.cast(meta),
      outputs: Output.cast_all(outputs),
      # paid and reward are hex strings decoded to binary (amount of VTHO in wei)
      paid: Utils.hex_decode!(paid),
      reverted: reverted,
      reward: Utils.hex_decode!(reward)
    }
  end

  defimpl Inspect do
    alias VeChain.Utils

    def inspect(tx_receipt, opts) do
      # Use the default struct inspection with the modified tx_receipt
      %{
        tx_receipt
        | gas_payer: Utils.hex_encode(tx_receipt.gas_payer),
          paid: Utils.hex_encode(tx_receipt.paid),
          reward: Utils.hex_encode(tx_receipt.reward)
      }
      |> Inspect.Any.inspect(opts)
    end
  end
end
