defmodule VeChain.Clause do
  @moduledoc """
  VeChain transaction clause struct and builders.

  A clause represents a single operation within a VeChain transaction.
  Transactions can contain multiple clauses, enabling atomic multi-task
  transactions.

  ## Clause Structure

  Each clause consists of:
  - `to`: Recipient address (20-byte binary, nil for contract creation)
  - `value`: Amount of VET to transfer (integer in wei)
  - `data`: Contract call data or deployment bytecode (binary)

  ## Internal Representation

  **IMPORTANT**: Clauses store addresses as 20-byte binaries internally,
  NOT hex strings. Use `VeChain.Utils.to_binary/1` to convert from hex
  strings when creating clauses.

  ## Examples

      # VET transfer
      clause = Clause.transfer_vet(
        "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
        VeChain.Utils.vet(10)
      )

      # Contract call (data is hex string, converted internally)
      clause = Clause.call_contract(
        "0xcontractaddress...",
        0,
        "0xa9059cbb..."  # Transfer function call
      )

      # Contract deployment
      clause = Clause.deploy_contract(
        "0x608060405234801561001057600080fd5b50..."  # Bytecode
      )

      # Manual construction
      clause = Clause.new(
        to: "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
        value: 1_000_000_000_000_000_000,  # 1 VET in wei
        data: ""
      )
  """

  alias VeChain.Utils

  @type t :: %__MODULE__{
          to: binary() | nil,
          value: non_neg_integer(),
          data: binary()
        }

  defstruct to: nil,
            value: 0,
            data: <<>>

  @doc """
  Creates a new clause.

  Accepts addresses as hex strings or binaries. Internally converts to binary.

  ## Parameters

    * `opts` - Keyword list with:
      - `:to` - Recipient address (hex string or binary, nil for contract creation)
      - `:value` - Amount in wei (integer, default: 0)
      - `:data` - Call data (hex string or binary, default: empty)

  ## Returns

  A new `Clause` struct.

  ## Examples

      iex> Clause.new(to: "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", value: 1000)
      %Clause{to: <<...>>, value: 1000, data: <<>>}

      iex> Clause.new(to: nil, data: "0x608060...")
      %Clause{to: nil, value: 0, data: <<...>>}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    to = opts[:to]
    value = opts[:value] || 0
    data = opts[:data] || <<>>

    %__MODULE__{
      to: to,
      value: value,
      data: normalize_data(data)
    }
  end

  @doc """

  """
  @spec cast_all([map()]) :: [t()]
  def cast_all([]), do: []

  def cast_all([clause | rest]) do
    [cast(clause) | cast_all(rest)]
  end

  @doc """
  Casts a map to a Clause struct.
  """
  @spec cast(map()) :: t()
  def cast(%{
        "to" => to,
        "value" => value,
        "data" => data
      }) do
    %__MODULE__{
      to: Utils.hex_decode!(to),
      value: Utils.hex_decode!(value),
      data: normalize_data(data)
    }
  end

  @doc """
  Creates a VET transfer clause.

  This is the most common clause type - transferring VET to an address.

  ## Parameters

    * `to` - Recipient address (hex string or binary)
    * `amount` - Amount in wei (use `VeChain.Utils.vet/1` for conversion)

  ## Returns

  A new `Clause` struct configured for VET transfer.

  ## Examples

      iex> Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", VeChain.Utils.vet(10))
      %Clause{to: <<...>>, value: 10_000_000_000_000_000_000, data: <<>>}

      iex> Clause.transfer_vet("0x7567...", 1_000_000_000_000_000_000)
      %Clause{to: <<...>>, value: 1_000_000_000_000_000_000, data: <<>>}
  """
  @spec transfer_vet(Types.t_address() | binary(), non_neg_integer()) :: t()
  def transfer_vet(to, amount) when is_integer(amount) and amount >= 0 do
    %__MODULE__{
      to: to,
      value: amount,
      data: <<>>
    }
  end

  @doc """
  Creates a contract call clause.

  Used to call a function on a deployed smart contract.

  ## Parameters

    * `to` - Contract address (hex string or binary)
    * `value` - Amount of VET to send (integer in wei, default: 0)
    * `data` - Encoded function call data (hex string or binary)

  ## Returns

  A new `Clause` struct configured for contract call.

  ## Examples

      # ERC20 transfer function call
      iex> data = "0xa9059cbb000000000000000000000000..."
      iex> Clause.call_contract("0xcontractaddr...", 0, data)
      %Clause{to: <<...>>, value: 0, data: <<...>>}

      # Payable contract call with VET
      iex> Clause.call_contract("0xcontractaddr...", VeChain.Utils.vet(1), "0x1234...")
      %Clause{to: <<...>>, value: 1_000_000_000_000_000_000, data: <<...>>}
  """
  @spec call_contract(Types.t_address() | binary(), non_neg_integer(), String.t() | binary()) ::
          t()
  def call_contract(to, value \\ 0, data)
      when is_integer(value) and value >= 0 do
    %__MODULE__{
      to: to,
      value: value,
      data: normalize_data(data)
    }
  end

  @doc """
  Creates a contract deployment clause.

  Used to deploy a new smart contract.

  ## Parameters

    * `bytecode` - Contract bytecode (hex string or binary)
    * `value` - Amount of VET to send to constructor (integer in wei, default: 0)

  ## Returns

  A new `Clause` struct configured for contract deployment.

  ## Examples

      iex> alias VeChain.Clause
      iex> bytecode = "0x6080604052"
      iex> clause = Clause.deploy_contract(bytecode)
      iex> clause.to
      nil
      iex> clause.value
      0
  """
  @spec deploy_contract(String.t() | binary(), non_neg_integer()) :: t()
  def deploy_contract(bytecode, value \\ 0) when is_integer(value) and value >= 0 do
    %__MODULE__{
      to: nil,
      value: value,
      data: normalize_data(bytecode)
    }
  end

  @doc """
  Encodes a clause for RLP encoding.

  Converts the clause struct to a list suitable for RLP encoding.
  This is used internally by the transaction encoding process.

  ## Parameters

    * `clause` - Clause struct to encode

  ## Returns

  List of `[to, value, data]` suitable for RLP encoding.

  ## Examples

      iex> clause = Clause.transfer_vet("0x7567...", 1000)
      iex> Clause.encode(clause)
      [<<...>>, 1000, <<>>]

      iex> clause = Clause.new(to: nil, data: "0x1234")
      iex> Clause.encode(clause)
      ["", 0, <<0x12, 0x34>>]
  """
  @spec encode(t()) :: list()
  def encode(%__MODULE__{to: to, value: value, data: data}) do
    [
      to || "",
      value,
      data
    ]
  end

  @doc """
  Decodes a clause from RLP-decoded list.

  Converts an RLP-decoded list back to a Clause struct.
  This is used internally by the transaction decoding process.

  ## Parameters

    * `list` - RLP-decoded list `[to, value, data]`

  ## Returns

  A `Clause` struct.

  ## Examples

      iex> Clause.decode([<<...>>, 1000, <<>>])
      %Clause{to: <<...>>, value: 1000, data: <<>>}

      iex> Clause.decode(["", 0, <<0x12, 0x34>>])
      %Clause{to: nil, value: 0, data: <<0x12, 0x34>>}
  """
  @spec decode(list()) :: t()
  def decode([to, value, data]) do
    %__MODULE__{
      to: decode_optional(to),
      value: to_integer(value),
      data: data
    }
  end

  defimpl Inspect do
    alias VeChain.Utils

    def inspect(clause, opts) do
      # Use the default struct inspection with the modified clause
      %{
        clause
        | to: Utils.hex_encode(clause.to),
          value: Utils.hex_encode(clause.value),
          data: Utils.hex_encode(clause.data)
      }
      |> Inspect.Any.inspect(opts)
    end
  end

  # Private helpers

  # Normalize data to binary format
  defp normalize_data(data) when data == "" or data == <<>> or data == "0x", do: <<>>

  defp normalize_data("0x" <> hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, binary} -> binary
      :error -> raise ArgumentError, "Invalid hex data"
    end
  end

  defp normalize_data(data) when is_binary(data) do
    # Assume it's already binary if no 0x prefix
    case Base.decode16(data, case: :mixed) do
      {:ok, binary} -> binary
      :error -> data
    end
  end

  # Decode optional fields - empty string becomes nil
  defp decode_optional(value) when value == "" or value == <<>>, do: nil
  defp decode_optional(value), do: value

  # Convert RLP-decoded values to integer
  defp to_integer(n) when is_integer(n), do: n
  defp to_integer(value) when value == "" or value == <<>>, do: 0

  defp to_integer(bin) when is_binary(bin) do
    :binary.decode_unsigned(bin, :big)
  end
end
