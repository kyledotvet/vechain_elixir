defmodule VeChain.Transaction.Clause do
  defstruct [
    :to,
    :value,
    :data
  ]

  alias Ethers.Types
  alias VeChain.Utils

  @type t() :: %__MODULE__{
          to: Types.t_address() | nil,
          value: binary(),
          data: binary()
        }

  def cast([to, value, data]) do
    %__MODULE__{
      to: to,
      value: value,
      data: data
    }
  end

  @spec from_contract_fn(Ethers.TxData.t(), non_neg_integer() | nil) ::
          VeChain.Transaction.Clause.t()
  def from_contract_fn(tx_data, value \\ 0)

  def from_contract_fn(
        %Ethers.TxData{
          default_address: to_address,
          data: data,
          selector: %ABI.FunctionSelector{
            state_mutability: :payable
          }
        },
        value
      ) do
    %__MODULE__{
      to: Utils.decode_address!(to_address),
      value: encode_value(value),
      data: data
    }
  end

  def from_contract_fn(
        %Ethers.TxData{
          default_address: to_address,
          data: data,
          selector: %ABI.FunctionSelector{
            state_mutability: :non_payable
          }
        },
        _value
      ) do
    %__MODULE__{
      to: to_address,
      value: <<>>,
      data: data
    }
  end

  def to_rlp_list(%__MODULE__{to: to, value: value, data: data}) do
    [
      to,
      value,
      data
    ]
  end

  @spec encode_value(non_neg_integer()) :: binary()
  def encode_value(0), do: <<>>
  def encode_value(value), do: :binary.encode_unsigned(value)

  @spec decode_value(binary()) :: String.t()
  def decode_value(<<>>), do: "0x0"
  def decode_value(value), do: Utils.hex_encode(value)

  defimpl ExRLP.Encode do
    alias VeChain.Transaction.Clause

    def encode(clause, options \\ []) do
      clause
      |> Clause.to_rlp_list()
      |> ExRLP.encode(options)
    end
  end

  defimpl Inspect do
    alias VeChain.Utils
    alias VeChain.Transaction.Clause

    def inspect(clause, opts) do
      %{
        clause
        | to: Utils.maybe_encode_address(clause.to),
          value: Clause.decode_value(clause.value) |> Utils.drop_leading_zeros(),
          data: Utils.hex_encode(clause.data)
      }
      |> Inspect.Any.inspect(opts)
    end
  end
end
