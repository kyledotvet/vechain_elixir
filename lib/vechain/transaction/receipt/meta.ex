defmodule VeChain.Transaction.Receipt.Meta do
  alias VeChain.Types
  alias VeChain.Utils

  defstruct [
    :block_id,
    :block_number,
    :block_timestamp,
    :tx_id,
    :tx_origin
  ]

  @type t :: %__MODULE__{
          block_id: Types.t_hash(),
          block_number: non_neg_integer(),
          block_timestamp: non_neg_integer(),
          tx_id: Types.t_hash(),
          tx_origin: Types.t_address()
        }

  def cast(%{
        "blockID" => block_id,
        "blockNumber" => block_number,
        "blockTimestamp" => block_timestamp,
        "txID" => tx_id,
        "txOrigin" => tx_origin
      }) do
    %__MODULE__{
      block_id: Utils.hex_decode!(block_id),
      block_number: block_number,
      block_timestamp: block_timestamp,
      tx_id: Utils.hex_decode!(tx_id),
      tx_origin: Utils.hex_decode!(tx_origin)
    }
  end

  defimpl Inspect do
    alias VeChain.Utils

    def inspect(tx_meta, opts) do
      # Use the default struct inspection with the modified tx_meta
      %{
        tx_meta
        | block_id: Utils.hex_encode(tx_meta.block_id),
          block_timestamp: DateTime.from_unix!(tx_meta.block_timestamp),
          tx_id: Utils.hex_encode(tx_meta.tx_id),
          tx_origin: Utils.hex_encode(tx_meta.tx_origin)
      }
      |> Inspect.Any.inspect(opts)
    end
  end
end
