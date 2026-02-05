defmodule VeChain.Block do
  @moduledoc """
  Represents a VeChain block with its associated fields.
  """
  alias Ethers.Types
  alias VeChain.Utils

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

  def cast(%{
        "baseFeePerGas" => base_fee_per_gas,
        "beneficiary" => beneficiary,
        "com" => com,
        "gasLimit" => gas_limit,
        "gasUsed" => gas_used,
        "id" => id,
        "isFinalized" => is_finalized,
        "isTrunk" => is_trunk,
        "number" => number,
        "parentID" => parent_id,
        "receiptsRoot" => receipts_root,
        "signer" => signer,
        "size" => size,
        "stateRoot" => state_root,
        "timestamp" => timestamp,
        "totalScore" => total_score,
        "transactions" => transactions,
        "txsFeatures" => txs_features,
        "txsRoot" => txs_root
      }) do
    %__MODULE__{
      number: number,
      id: Utils.hex_decode!(id),
      size: size,
      parent_id: Utils.hex_decode!(parent_id),
      timestamp: DateTime.from_unix!(timestamp),
      gas_limit: gas_limit,
      beneficiary: Utils.hex_decode!(beneficiary),
      gas_used: gas_used,
      base_fee_per_gas: Utils.hex_decode!(base_fee_per_gas),
      total_score: total_score,
      txs_root: Utils.hex_decode!(txs_root),
      txs_features: txs_features,
      state_root: Utils.hex_decode!(state_root),
      receipts_root: Utils.hex_decode!(receipts_root),
      com: com,
      signer: Utils.hex_decode!(signer),
      is_trunk: is_trunk,
      is_finalized: is_finalized,
      transactions: transactions
    }
  end

  def get_block_ref(%__MODULE__{id: <<first_8::binary-size(8), _rest::binary>>}) do
    first_8
  end

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
