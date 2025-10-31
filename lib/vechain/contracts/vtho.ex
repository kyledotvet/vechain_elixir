defmodule VeChain.Contracts.VTHO do
  @moduledoc """
  VTHO (VeThor) token contract interface.

  VTHO is VeChain's gas token, generated automatically by holding VET.
  It follows the VIP-180 standard (compatible with ERC-20).

  The VTHO contract is deployed at the same address on all networks:
  `0x0000000000000000000000000000456E65726779`

  ## Examples

      # Get VTHO balance
      iex> VeChain.Contracts.VTHO.balance_of(
      ...>   "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
      ...>   network: :testnet
      ...> )
      {:ok, 1000000000000000000000}

      # Create transfer clause
      iex> clause = VeChain.Contracts.VTHO.transfer(
      ...>   "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
      ...>   1000
      ...> )
  """

  alias VeChain.{Clause, Client.Thor, ABI, Utils}

  # VTHO contract address (same on all networks)
  # This is the hex encoding of "Energy" with proper casing
  @vtho_address "0x0000000000000000000000000000456E65726779"

  @doc """
  Get VTHO contract address.

  The address is the same on all networks.

  ## Examples

      iex> VeChain.Contracts.VTHO.address()
      "0x0000000000000000000000000000456E65726779"
  """
  @spec address() :: String.t()
  def address, do: @vtho_address

  @doc """
  Get token name.

  ## Parameters

  - `opts` - Options (`:network`, `:client`)

  ## Examples

      iex> VeChain.Contracts.VTHO.name(network: :mainnet)
      {:ok, "VeThor"}
  """
  @spec name(keyword()) :: {:ok, String.t()} | {:error, term()}
  def name(opts \\ []) do
    call_contract("name", [], ["string"], opts)
  end

  @doc """
  Get token symbol.

  ## Parameters

  - `opts` - Options (`:network`, `:client`)

  ## Examples

      iex> VeChain.Contracts.VTHO.symbol(network: :mainnet)
      {:ok, "VTHO"}
  """
  @spec symbol(keyword()) :: {:ok, String.t()} | {:error, term()}
  def symbol(opts \\ []) do
    call_contract("symbol", [], ["string"], opts)
  end

  @doc """
  Get token decimals.

  VTHO has 18 decimals.

  ## Parameters

  - `opts` - Options (`:network`, `:client`)

  ## Examples

      iex> VeChain.Contracts.VTHO.decimals(network: :mainnet)
      {:ok, 18}
  """
  @spec decimals(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def decimals(opts \\ []) do
    call_contract("decimals", [], ["uint8"], opts)
  end

  @doc """
  Get total VTHO supply.

  ## Parameters

  - `opts` - Options (`:network`, `:client`)

  ## Examples

      iex> VeChain.Contracts.VTHO.total_supply(network: :mainnet)
      {:ok, 39000000000000000000000000000}
  """
  @spec total_supply(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def total_supply(opts \\ []) do
    call_contract("totalSupply", [], ["uint256"], opts)
  end

  @doc """
  Get VTHO balance of an address.

  ## Parameters

  - `address` - Address to check (hex string with 0x prefix)
  - `opts` - Options (`:network`, `:client`, `:block`)

  ## Examples

      iex> VeChain.Contracts.VTHO.balance_of(
      ...>   "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
      ...>   network: :testnet
      ...> )
      {:ok, 1000000000000000000000}
  """
  @spec balance_of(String.t(), keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def balance_of(address, opts \\ []) when is_binary(address) do
    unless Utils.valid_address?(address) do
      {:error, :invalid_address}
    else
      call_contract("balanceOf", ["address"], ["uint256"], [address], opts)
    end
  end

  @doc """
  Get VTHO balance. Raises on error.
  """
  @spec balance_of!(String.t(), keyword()) :: non_neg_integer()
  def balance_of!(address, opts \\ []) do
    case balance_of(address, opts) do
      {:ok, balance} -> balance
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get balance: #{inspect(error)}"
    end
  end

  @doc """
  Get allowance for a spender.

  Returns the amount of VTHO that `spender` is allowed to spend on behalf of `owner`.

  ## Parameters

  - `owner` - Owner address
  - `spender` - Spender address
  - `opts` - Options (`:network`, `:client`, `:block`)

  ## Examples

      iex> VeChain.Contracts.VTHO.allowance(
      ...>   "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
      ...>   "0x1234567890123456789012345678901234567890",
      ...>   network: :testnet
      ...> )
      {:ok, 5000}
  """
  @spec allowance(String.t(), String.t(), keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def allowance(owner, spender, opts \\ []) when is_binary(owner) and is_binary(spender) do
    unless Utils.valid_address?(owner) and Utils.valid_address?(spender) do
      {:error, :invalid_address}
    else
      call_contract("allowance", ["address", "address"], ["uint256"], [owner, spender], opts)
    end
  end

  @doc """
  Get allowance. Raises on error.
  """
  @spec allowance!(String.t(), String.t(), keyword()) :: non_neg_integer()
  def allowance!(owner, spender, opts \\ []) do
    case allowance(owner, spender, opts) do
      {:ok, allowance} -> allowance
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get allowance: #{inspect(error)}"
    end
  end

  # Write functions (return clauses, not results)

  @doc """
  Create a VTHO transfer clause.

  This returns a clause that can be added to a transaction.
  To execute the transfer, add the clause to a transaction and sign/broadcast it.

  ## Parameters

  - `to` - Recipient address (hex string)
  - `amount` - Amount to transfer (in wei, 18 decimals)

  ## Examples

      iex> clause = VeChain.Contracts.VTHO.transfer(
      ...>   "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
      ...>   VeChain.Units.vtho(10)
      ...> )
      iex> VeChain.Transaction.new()
      ...> |> VeChain.Transaction.add_clause(clause)
      ...> |> VeChain.Transaction.sign(private_key)
      ...> |> VeChain.Transaction.broadcast()
  """
  @spec transfer(String.t(), non_neg_integer()) :: Clause.t()
  def transfer(to, amount) when is_binary(to) and is_integer(amount) and amount >= 0 do
    unless Utils.valid_address?(to) do
      raise VeChain.Error.InvalidAddress, message: "Invalid recipient address"
    end

    data = ABI.Encoder.encode_function_call!("transfer", ["address", "uint256"], [to, amount])

    Clause.call_contract(@vtho_address, data)
  end

  @doc """
  Create an approve clause.

  Allows `spender` to withdraw up to `amount` from the caller's account.

  ## Parameters

  - `spender` - Spender address
  - `amount` - Amount to approve

  ## Examples

      iex> clause = VeChain.Contracts.VTHO.approve(
      ...>   "0x1234567890123456789012345678901234567890",
      ...>   VeChain.Units.vtho(100)
      ...> )
  """
  @spec approve(String.t(), non_neg_integer()) :: Clause.t()
  def approve(spender, amount) when is_binary(spender) and is_integer(amount) and amount >= 0 do
    unless Utils.valid_address?(spender) do
      raise VeChain.Error.InvalidAddress, message: "Invalid spender address"
    end

    data = ABI.Encoder.encode_function_call!("approve", ["address", "uint256"], [spender, amount])

    Clause.call_contract(@vtho_address, data)
  end

  @doc """
  Create a transferFrom clause.

  Transfers `amount` from `from` to `to` using the allowance mechanism.
  The caller must have allowance to spend from the `from` address.

  ## Parameters

  - `from` - Sender address
  - `to` - Recipient address
  - `amount` - Amount to transfer

  ## Examples

      iex> clause = VeChain.Contracts.VTHO.transfer_from(
      ...>   "0x1111111111111111111111111111111111111111",
      ...>   "0x2222222222222222222222222222222222222222",
      ...>   VeChain.Units.vtho(50)
      ...> )
  """
  @spec transfer_from(String.t(), String.t(), non_neg_integer()) :: Clause.t()
  def transfer_from(from, to, amount)
      when is_binary(from) and is_binary(to) and is_integer(amount) and amount >= 0 do
    unless Utils.valid_address?(from) and Utils.valid_address?(to) do
      raise VeChain.Error.InvalidAddress, message: "Invalid address"
    end

    data =
      ABI.Encoder.encode_function_call!(
        "transferFrom",
        ["address", "address", "uint256"],
        [from, to, amount]
      )

    Clause.call_contract(@vtho_address, data)
  end

  # Private helper functions

  @spec call_contract(String.t(), [String.t()], [String.t()], keyword()) ::
          {:ok, any()} | {:error, term()}
  defp call_contract(function_name, input_types, output_types, opts) do
    call_contract(function_name, input_types, output_types, [], opts)
  end

  @spec call_contract(String.t(), [String.t()], [String.t()], [any()], keyword()) ::
          {:ok, any()} | {:error, term()}
  defp call_contract(function_name, input_types, output_types, args, opts) do
    with {:ok, data} <- ABI.Encoder.encode_function_call(function_name, input_types, args),
         client <- Keyword.get(opts, :client) || Thor.default_client(),
         {:ok, result} <- Thor.call_contract(client, @vtho_address, data, opts),
         {:ok, [decoded]} <- ABI.Decoder.decode_function_return(output_types, result["data"]) do
      {:ok, decoded}
    end
  end
end
