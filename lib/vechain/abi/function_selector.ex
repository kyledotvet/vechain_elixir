defmodule VeChain.ABI.FunctionSelector do
  @moduledoc """
  Generate function selectors for ABI function calls.

  Function selectors are the first 4 bytes of the Keccak-256 hash
  of the function signature. This follows Ethereum's ABI standard.

  ## Examples

      iex> VeChain.ABI.FunctionSelector.encode("transfer(address,uint256)")
      <<0xa9, 0x05, 0x9c, 0xbb>>

      iex> VeChain.ABI.FunctionSelector.encode_hex("balanceOf(address)")
      "0x70a08231"
  """

  @doc """
  Generate function selector from function signature.

  Returns the first 4 bytes of the Keccak-256 hash of the signature.

  ## Parameters

  - `signature` - Function signature string (e.g., "transfer(address,uint256)")

  ## Examples

      iex> VeChain.ABI.FunctionSelector.encode("transfer(address,uint256)")
      <<0xa9, 0x05, 0x9c, 0xbb>>
  """
  @spec encode(String.t()) :: <<_::32>>
  def encode(signature) when is_binary(signature) do
    signature
    |> ExKeccak.hash_256()
    |> binary_part(0, 4)
  end

  @doc """
  Generate function selector as hex string.

  ## Parameters

  - `signature` - Function signature string

  ## Examples

      iex> VeChain.ABI.FunctionSelector.encode_hex("balanceOf(address)")
      "0x70a08231"
  """
  @spec encode_hex(String.t()) :: String.t()
  def encode_hex(signature) when is_binary(signature) do
    selector = encode(signature)
    "0x" <> Base.encode16(selector, case: :lower)
  end

  @doc """
  Decode function selector from data.

  Extracts the first 4 bytes from calldata.

  ## Parameters

  - `data` - Binary data or hex string containing the selector

  ## Examples

      iex> VeChain.ABI.FunctionSelector.decode(<<0xa9, 0x05, 0x9c, 0xbb, 0x00, 0x00>>)
      {:ok, <<0xa9, 0x05, 0x9c, 0xbb>>}

      iex> VeChain.ABI.FunctionSelector.decode("0xa9059cbb0000")
      {:ok, <<0xa9, 0x05, 0x9c, 0xbb>>}
  """
  @spec decode(binary() | String.t()) :: {:ok, <<_::32>>} | {:error, :invalid_data}
  def decode(data) when is_binary(data) do
    # Handle hex string input
    binary =
      if String.starts_with?(data, "0x") do
        case Base.decode16(String.slice(data, 2..-1//1), case: :mixed) do
          {:ok, bin} -> bin
          :error -> data
        end
      else
        data
      end

    if byte_size(binary) >= 4 do
      {:ok, binary_part(binary, 0, 4)}
    else
      {:error, :invalid_data}
    end
  end

  @doc """
  Decode function selector. Raises on error.

  ## Parameters

  - `data` - Binary data containing the selector

  ## Examples

      iex> VeChain.ABI.FunctionSelector.decode!(<<0xa9, 0x05, 0x9c, 0xbb>>)
      <<0xa9, 0x05, 0x9c, 0xbb>>
  """
  @spec decode!(binary() | String.t()) :: <<_::32>>
  def decode!(data) do
    case decode(data) do
      {:ok, selector} -> selector
      {:error, reason} -> raise VeChain.Error.EncodingError, message: "Failed to decode selector: #{reason}"
    end
  end

  @doc """
  Common function selectors for ERC20/VIP-180 tokens.

  Returns a map of function names to their selectors.
  """
  @spec common_selectors() :: %{atom() => binary()}
  def common_selectors do
    %{
      transfer: encode("transfer(address,uint256)"),
      transfer_from: encode("transferFrom(address,address,uint256)"),
      approve: encode("approve(address,uint256)"),
      balance_of: encode("balanceOf(address)"),
      allowance: encode("allowance(address,address)"),
      total_supply: encode("totalSupply()"),
      name: encode("name()"),
      symbol: encode("symbol()"),
      decimals: encode("decimals()")
    }
  end
end
