defmodule VeChain.Block do
  @moduledoc """
  Represents a VeChain block with its associated fields.
  """

  alias VeChain.Types

  defstruct [
    :number,
    :id,
    :size,
    :parent_id,
    :timestamp,
    :gas_limit,
    :beneficiary,
    :gas_used,
    :base_fee_per_gas,
    :total_score,
    :txs_root,
    :txs_features,
    :state_root,
    :receipts_root,
    :com,
    :signer,
    :is_trunk,
    :is_finalized,
    :transactions
  ]

  @type t :: %__MODULE__{
          number: non_neg_integer(),
          id: Types.t_hash(),
          size: non_neg_integer(),
          parent_id: Types.t_hash(),
          timestamp: non_neg_integer(),
          gas_limit: non_neg_integer(),
          beneficiary: Types.t_address(),
          gas_used: non_neg_integer(),
          base_fee_per_gas: String.t() | nil,
          total_score: non_neg_integer(),
          txs_root: Types.t_hash(),
          txs_features: non_neg_integer(),
          state_root: Types.t_hash(),
          receipts_root: Types.t_hash(),
          com: boolean(),
          signer: Types.t_address(),
          is_trunk: boolean(),
          is_finalized: boolean(),
          transactions: [Types.t_hash()]
        }

  defimpl Inspect do
    alias VeChain.Utils

    def inspect(block, opts) do
      # Use the default struct inspection with the modified block
      %{
        block
        | id: Utils.hex_encode(block.id),
          parent_id: Utils.hex_encode(block.parent_id),
          beneficiary: Utils.hex_encode(block.beneficiary),
          base_fee_per_gas: Utils.hex_encode(block.base_fee_per_gas),
          txs_root: Utils.hex_encode(block.txs_root),
          state_root: Utils.hex_encode(block.state_root),
          receipts_root: Utils.hex_encode(block.receipts_root),
          signer: Utils.hex_encode(block.signer)
      }
      |> Inspect.Any.inspect(opts)
    end
  end
end
