defmodule VeChain.Contracts.Executor do
  @moduledoc """
  VIP-191 Executor contract interface.

  The Executor contract manages fee delegation (VIP-191) on VeChain.
  It allows transactions to be sponsored by a different account than the sender.

  The contract address can be retrieved from the Params contract via the
  "executor-address" key.

  ## VIP-191 Fee Delegation

  Fee delegation allows a "gas payer" to pay for transaction fees on behalf
  of the transaction sender. This is useful for:
  - User onboarding (app pays gas for new users)
  - Enterprise use cases (company pays gas for employees)
  - Improving user experience

  ## Examples

      # Check if an address is approved as a gas payer
      iex> VeChain.Contracts.Executor.is_approved(
      ...>   "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
      ...>   "0x1234567890123456789012345678901234567890",
      ...>   network: :testnet
      ...> )
      {:ok, true}
  """

  alias VeChain.{Client.Thor, ABI, Utils, Contracts.Params}

  @doc """
  Get the Executor contract address from the Params contract.

  ## Parameters

  - `opts` - Options (`:network`, `:client`, `:block`)

  ## Returns

  - `{:ok, address}` - Executor contract address (hex string)
  - `{:error, reason}` - Error details

  ## Examples

      iex> VeChain.Contracts.Executor.address(network: :mainnet)
      {:ok, "0x7873c7d9d3ce7ffdea561b508edcac9ff4caedeb"}
  """
  @spec address(keyword()) :: {:ok, String.t()} | {:error, term()}
  def address(opts \\ []) do
    with {:ok, address_bytes} <- Params.executor_address(opts) do
      # Extract the last 20 bytes (address is padded to 32 bytes)
      address_binary = binary_part(address_bytes, 12, 20)
      {:ok, Utils.encode_address!(address_binary)}
    end
  end

  @doc """
  Get the Executor contract address. Raises on error.
  """
  @spec address!(keyword()) :: String.t()
  def address!(opts \\ []) do
    case address(opts) do
      {:ok, addr} -> addr
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get executor address: #{inspect(error)}"
    end
  end

  @doc """
  Check if a gas payer is approved for a sender.

  VIP-191 requires explicit approval before a gas payer can sponsor
  transactions for a sender.

  ## Parameters

  - `sender` - Transaction sender address (hex string)
  - `gas_payer` - Gas payer address (hex string)
  - `opts` - Options (`:network`, `:client`, `:block`)

  ## Returns

  - `{:ok, true}` - Gas payer is approved
  - `{:ok, false}` - Gas payer is not approved
  - `{:error, reason}` - Error details

  ## Examples

      iex> VeChain.Contracts.Executor.is_approved(
      ...>   "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
      ...>   "0x1234567890123456789012345678901234567890",
      ...>   network: :testnet
      ...> )
      {:ok, true}
  """
  @spec is_approved(String.t(), String.t(), keyword()) :: {:ok, boolean()} | {:error, term()}
  def is_approved(sender, gas_payer, opts \\ [])
      when is_binary(sender) and is_binary(gas_payer) do
    unless Utils.valid_address?(sender) and Utils.valid_address?(gas_payer) do
      {:error, :invalid_address}
    else
      with {:ok, executor_addr} <- address(opts),
           {:ok, data} <- ABI.Encoder.encode_function_call(
             "approvedList",
             ["address", "address"],
             [sender, gas_payer]
           ),
           client <- Keyword.get(opts, :client) || Thor.default_client(),
           {:ok, result} <- Thor.call_contract(client, executor_addr, data, opts),
           {:ok, [approved]} <- ABI.Decoder.decode_function_return(["bool"], result["data"]) do
        {:ok, approved}
      end
    end
  end

  @doc """
  Check if a gas payer is approved. Raises on error.
  """
  @spec is_approved!(String.t(), String.t(), keyword()) :: boolean()
  def is_approved!(sender, gas_payer, opts \\ []) do
    case is_approved(sender, gas_payer, opts) do
      {:ok, approved} -> approved
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to check approval: #{inspect(error)}"
    end
  end

  @doc """
  Create a clause to approve a gas payer.

  This allows the gas payer to sponsor transactions on behalf of the sender.

  ## Parameters

  - `gas_payer` - Gas payer address to approve (hex string)
  - `opts` - Options (`:network` to determine executor address)

  ## Returns

  A clause for approving the gas payer.

  ## Examples

      iex> clause = VeChain.Contracts.Executor.approve(
      ...>   "0x1234567890123456789012345678901234567890",
      ...>   network: :testnet
      ...> )
      iex> # Add to transaction and sign with sender's key
      iex> VeChain.Transaction.new()
      ...> |> VeChain.Transaction.add_clause(clause)
      ...> |> VeChain.Transaction.run(private_key: sender_key)
  """
  @spec approve(String.t(), keyword()) :: VeChain.Clause.t()
  def approve(gas_payer, opts \\ []) when is_binary(gas_payer) do
    unless Utils.valid_address?(gas_payer) do
      raise VeChain.Error.InvalidAddress, message: "Invalid gas payer address"
    end

    executor_addr = address!(opts)

    # Encode function call: addApprovedList(address)
    data = ABI.Encoder.encode_function_call!("addApprovedList", ["address"], [gas_payer])

    VeChain.Clause.call_contract(executor_addr, 0, data)
  end

  @doc """
  Create a clause to revoke approval for a gas payer.

  This prevents the gas payer from sponsoring future transactions.

  ## Parameters

  - `gas_payer` - Gas payer address to revoke (hex string)
  - `opts` - Options (`:network` to determine executor address)

  ## Returns

  A clause for revoking the gas payer's approval.

  ## Examples

      iex> clause = VeChain.Contracts.Executor.revoke(
      ...>   "0x1234567890123456789012345678901234567890",
      ...>   network: :testnet
      ...> )
  """
  @spec revoke(String.t(), keyword()) :: VeChain.Clause.t()
  def revoke(gas_payer, opts \\ []) when is_binary(gas_payer) do
    unless Utils.valid_address?(gas_payer) do
      raise VeChain.Error.InvalidAddress, message: "Invalid gas payer address"
    end

    executor_addr = address!(opts)

    # Encode function call: removeApprovedList(address)
    data = ABI.Encoder.encode_function_call!("removeApprovedList", ["address"], [gas_payer])

    VeChain.Clause.call_contract(executor_addr, 0, data)
  end

  @doc """
  Check the current credit balance for a sponsor.

  The credit system allows sponsors to set credit limits for users.

  ## Parameters

  - `sponsor` - Sponsor address (hex string)
  - `user` - User address (hex string)
  - `opts` - Options (`:network`, `:client`, `:block`)

  ## Returns

  - `{:ok, credit}` - Current credit balance (uint256)
  - `{:error, reason}` - Error details

  ## Examples

      iex> VeChain.Contracts.Executor.get_credit(
      ...>   "0x1234567890123456789012345678901234567890",
      ...>   "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
      ...>   network: :testnet
      ...> )
      {:ok, 1000000}
  """
  @spec get_credit(String.t(), String.t(), keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def get_credit(sponsor, user, opts \\ [])
      when is_binary(sponsor) and is_binary(user) do
    unless Utils.valid_address?(sponsor) and Utils.valid_address?(user) do
      {:error, :invalid_address}
    else
      with {:ok, executor_addr} <- address(opts),
           {:ok, data} <- ABI.Encoder.encode_function_call(
             "currentCreditPlan",
             ["address", "address"],
             [sponsor, user]
           ),
           client <- Keyword.get(opts, :client) || Thor.default_client(),
           {:ok, result} <- Thor.call_contract(client, executor_addr, data, opts),
           {:ok, [credit, _recovery_rate]} <- ABI.Decoder.decode_function_return(
             ["uint256", "uint256"],
             result["data"]
           ) do
        {:ok, credit}
      end
    end
  end

  @doc """
  Get the current credit balance. Raises on error.
  """
  @spec get_credit!(String.t(), String.t(), keyword()) :: non_neg_integer()
  def get_credit!(sponsor, user, opts \\ []) do
    case get_credit(sponsor, user, opts) do
      {:ok, credit} -> credit
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get credit: #{inspect(error)}"
    end
  end
end
