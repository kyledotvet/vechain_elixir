defmodule VeChain.Transaction.Output do
  alias VeChain.Types
  alias VeChain.Utils
  alias VeChain.Transaction.Event
  alias VeChain.Transaction.Transfer

  defstruct [
    :contract_address,
    :events,
    :transfers
  ]

  @type t :: %__MODULE__{
          contract_address: Types.t_address() | nil,
          events: [VeChain.Transaction.Event.t()],
          transfers: [VeChain.Transaction.Transfer.t()]
        }

  def cast_all([]), do: []

  def cast_all([output | rest]) do
    [cast(output) | cast_all(rest)]
  end

  def cast(%{
        "contractAddress" => contract_address,
        "events" => events,
        "transfers" => transfers
      }) do
    %__MODULE__{
      contract_address: VeChain.Utils.maybe_hex_decode(contract_address),
      events: Event.cast_all(events),
      transfers: Transfer.cast_all(transfers)
    }
  end

  defimpl Inspect do
    alias VeChain.Utils

    def inspect(tx_output, opts) do
      # Use the default struct inspection with the modified tx_output
      %{
        tx_output
        | contract_address: Utils.hex_encode(tx_output.contract_address)
      }
      |> Inspect.Any.inspect(opts)
    end
  end
end
