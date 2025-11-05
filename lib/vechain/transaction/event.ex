defmodule VeChain.Transaction.Event do
  alias VeChain.Types
  alias VeChain.Utils

  defstruct [
    :address,
    :topics,
    :data
  ]

  @type t :: %__MODULE__{
          address: Types.t_address(),
          topics: [Types.t_hash()],
          data: binary()
        }

  def cast_all([]), do: []

  def cast_all([event | rest]) do
    [cast(event) | cast_all(rest)]
  end

  def cast(%{
        "address" => address,
        "topics" => topics,
        "data" => data
      }) do
    %__MODULE__{
      address: Utils.hex_decode!(address),
      topics: Enum.map(topics, &Utils.hex_decode!/1),
      data: Utils.hex_decode!(data)
    }
  end

  defimpl Inspect do
    alias VeChain.Utils

    def inspect(tx_event, opts) do
      # Use the default struct inspection with the modified tx_event
      %{
        tx_event
        | address: Utils.hex_encode(tx_event.address),
          topics: Enum.map(tx_event.topics, &Utils.hex_encode/1),
          data: Utils.hex_encode(tx_event.data)
      }
      |> Inspect.Any.inspect(opts)
    end
  end
end
