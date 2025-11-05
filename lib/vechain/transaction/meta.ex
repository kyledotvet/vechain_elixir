defmodule VeChain.Transaction.Meta do
  alias VeChain.Types
  alias VeChain.Utils

  defstruct [
    :block_id,
    :block_number,
    :block_timestamp
  ]

  @type t :: %__MODULE__{
          block_id: Types.t_hash(),
          block_number: non_neg_integer(),
          block_timestamp: non_neg_integer()
        }

  def cast(%{
        "blockID" => block_id,
        "blockNumber" => block_number,
        "blockTimestamp" => block_timestamp
      }) do
    %__MODULE__{
      block_id: Utils.hex_decode!(block_id),
      block_number: block_number,
      block_timestamp: block_timestamp
    }
  end

  defimpl Inspect do
    alias VeChain.Utils

    def inspect(tx_meta, opts) do
      # Use the default struct inspection with the modified tx_meta
      %{
        tx_meta
        | block_id: Utils.hex_encode(tx_meta.block_id),
          block_timestamp: DateTime.from_unix!(tx_meta.block_timestamp)
      }
      |> Inspect.Any.inspect(opts)
    end
  end
end
