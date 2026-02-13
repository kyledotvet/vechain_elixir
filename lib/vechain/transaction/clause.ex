defmodule VeChain.Transaction.Clause do
  defstruct [
    :to,
    :value,
    :data
  ]

  alias Ethers.Types
  alias VeChain.Utils

  @type t() :: t_vet_transfer() | t_contract_deployment() | t_contract_fn_call()

  @type t_vet_transfer() :: %__MODULE__{
          to: <<_::160>>,
          value: binary(),
          data: <<>>
        }

  @type t_contract_deployment() :: %__MODULE__{
          to: <<>>,
          value: binary(),
          data: binary()
        }

  @type t_contract_fn_call() :: %__MODULE__{
          to: <<_::160>>,
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

  @doc """
  Parses clauses coming from options passed in while creating a new transaction (see `VeChain.Transaction.new/1`),
  converting them to Clause structs and validating their format.
  """
  def parse_clauses(config, opts) do
    parsed_clauses =
      opts
      |> Keyword.get(:clauses, [])
      |> Enum.map(&new/1)

    Map.put(config, :clauses, parsed_clauses)
  end

  @spec new(
          t()
          | {Ethers.TxData.t(), non_neg_integer()}
          | Ethers.TxData.t()
          | map()
        ) :: t()
  def new(%__MODULE__{} = clause), do: clause
  def new({%Ethers.TxData{} = tx_data, value}), do: from_contract_fn(tx_data, value)
  def new(%Ethers.TxData{} = tx_data), do: from_contract_fn(tx_data)

  def new(%{to: to_address, value: value, data: data}) when is_binary(data) do
    %__MODULE__{
      to: validate_clause_address(to_address, data),
      value: encode_value(value),
      data: data
    }
  end

  def new(%{to: to_address, data: data}) when is_binary(data) and byte_size(data) > 0 do
    %__MODULE__{
      to: validate_clause_address(to_address, data),
      value: <<>>,
      data: data
    }
  end

  def new(%{to: to_address, value: value}) do
    %__MODULE__{
      to: validate_clause_address(to_address, <<>>),
      value: encode_value(value),
      data: <<>>
    }
  end

  def new(clause), do: raise(ArgumentError, "Invalid clause format: #{inspect(clause)}")

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
      to: validate_clause_address(to_address, data),
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
      to: validate_clause_address(to_address, data),
      value: <<>>,
      data: data
    }
  end

  @spec transfer_vet(Types.t_address(), pos_integer()) :: t()
  def transfer_vet("0x" <> _rest = to_address, amount_in_wei) do
    to_address
    |> Utils.decode_address!()
    |> transfer_vet(amount_in_wei)
  end

  def transfer_vet(to_address, amount_in_wei) do
    %__MODULE__{
      to: validate_clause_address(to_address, <<>>),
      value: encode_value(amount_in_wei),
      data: <<>>
    }
  end

  defp validate_clause_address("0x" <> _hex = address, data) do
    address
    |> Utils.decode_address!()
    |> validate_clause_address(data)
  end

  defp validate_clause_address(nil, data) when is_binary(data) and byte_size(data) > 0 do
    <<>>
  end

  defp validate_clause_address(nil, <<>>) do
    raise ArgumentError, "To address cannot be nil for a clause with empty data"
  end

  defp validate_clause_address(address, _data)
       when is_binary(address) and byte_size(address) == 20 do
    address
  end

  defp validate_clause_address(_address, _data) do
    raise ArgumentError,
          "To address must be a binary 20 bytes (or 40 hex characters beginning with 0x)"
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

  def encode_value(value) do
    value
    |> :binary.encode_unsigned()
    |> validate_value()
  end

  defp validate_value(value) when is_binary(value) and byte_size(value) <= 32 do
    value
  end

  defp validate_value(_value) do
    raise ArgumentError, "Value must be a non-negative integer of up to 32 bytes (< 2^256)"
  end

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
