defmodule VeChain.Transaction.Clause do
  defstruct [
    :to,
    :value,
    :data
  ]

  alias VeChain.Transaction.Encoder
  alias VeChain.Utils

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
      to: to_address,
      value: value,
      data: "0x" <> data
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
      value: 0,
      data: "0x" <> data
    }
  end

  def to_rlp_list(%__MODULE__{to: to, value: value, data: data}) do
    [
      Encoder.optional_fixed_length_binary(to, 20),
      encode_value(value),
      Utils.hex_decode!(data)
    ]
  end

  def encode_value(0), do: <<>>
  def encode_value(value), do: :binary.encode_unsigned(value)

  defimpl ExRLP.Encode do
    alias VeChain.Transaction.Clause

    def encode(clause, options \\ []) do
      clause
      |> Clause.to_rlp_list()
      |> ExRLP.encode(options)
    end
  end
end
