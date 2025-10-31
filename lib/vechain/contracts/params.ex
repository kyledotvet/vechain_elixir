defmodule VeChain.Contracts.Params do
  @moduledoc """
  Network parameters contract interface.

  The Params contract stores governance parameters for the VeChain network,
  such as base gas price, block reward, and other network-wide settings.

  The contract is deployed at the same address on all networks:
  `0x0000000000000000000000000000506172616d73`

  ## Examples

      # Get base gas price
      iex> VeChain.Contracts.Params.get("base-gas-price", network: :mainnet)
      {:ok, 1000000000000000}

      # Get block reward
      iex> VeChain.Contracts.Params.get("reward-ratio", network: :mainnet)
      {:ok, 300000000000000000000000000}
  """

  alias VeChain.{Client.Thor, ABI}

  # Params contract address (same on all networks)
  # This is the hex encoding of "Params"
  @params_address "0x0000000000000000000000000000506172616d73"

  # Known parameter keys
  @executor_address "executor-address"
  @reward_ratio "reward-ratio"
  @base_gas_price "base-gas-price"
  @proposer_endorsement "proposer-endorsement"
  @block_interval "block-interval"

  @doc """
  Get Params contract address.

  The address is the same on all networks.

  ## Examples

      iex> VeChain.Contracts.Params.address()
      "0x0000000000000000000000000000506172616d73"
  """
  @spec address() :: String.t()
  def address, do: @params_address

  @doc """
  Get a parameter value by key.

  ## Parameters

  - `key` - Parameter key (string, e.g., "base-gas-price")
  - `opts` - Options (`:network`, `:client`, `:block`)

  ## Returns

  - `{:ok, value}` - Parameter value (bytes32)
  - `{:error, reason}` - Error details

  ## Common Parameter Keys

  - `"executor-address"` - VIP-191 executor contract address
  - `"reward-ratio"` - Block reward distribution ratio
  - `"base-gas-price"` - Base gas price in wei
  - `"proposer-endorsement"` - Proposer endorsement threshold
  - `"block-interval"` - Target block interval in seconds

  ## Examples

      iex> VeChain.Contracts.Params.get("base-gas-price", network: :mainnet)
      {:ok, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 141, 126, 164, 198, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}
  """
  @spec get(String.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def get(key, opts \\ []) when is_binary(key) do
    # Convert key to bytes32 (keccak256 hash of the key)
    key_hash = ExKeccak.hash_256(key)

    # Encode function call: get(bytes32)
    with {:ok, data} <- ABI.Encoder.encode_function_call("get", ["bytes32"], [key_hash]),
         client <- Keyword.get(opts, :client) || Thor.default_client(),
         {:ok, result} <- Thor.call_contract(client, @params_address, data, opts),
         {:ok, [value]} <- ABI.Decoder.decode_function_return(["bytes32"], result["data"]) do
      {:ok, value}
    end
  end

  @doc """
  Get a parameter value. Raises on error.
  """
  @spec get!(String.t(), keyword()) :: binary()
  def get!(key, opts \\ []) do
    case get(key, opts) do
      {:ok, value} -> value
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get param: #{inspect(error)}"
    end
  end

  @doc """
  Set a parameter value (requires authority).

  This creates a clause that can be added to a transaction.
  Only authority nodes can execute parameter changes through governance.

  ## Parameters

  - `key` - Parameter key (string)
  - `value` - Parameter value (bytes32)

  ## Returns

  A clause for setting the parameter.

  ## Examples

      iex> clause = VeChain.Contracts.Params.set("base-gas-price", <<0, 0, ...>>)
      iex> # Add to transaction and sign with authority key
  """
  @spec set(String.t(), binary()) :: VeChain.Clause.t()
  def set(key, value) when is_binary(key) and is_binary(value) do
    # Convert key to bytes32 hash
    key_hash = ExKeccak.hash_256(key)

    # Encode function call: set(bytes32,bytes32)
    data = ABI.Encoder.encode_function_call!("set", ["bytes32", "bytes32"], [key_hash, value])

    VeChain.Clause.call_contract(@params_address, 0, data)
  end

  # Convenience functions for common parameters

  @doc """
  Get the executor contract address.

  ## Examples

      iex> VeChain.Contracts.Params.executor_address(network: :mainnet)
      {:ok, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 120, 115, 199, 217, 211, 206, 127, 253, 234, 86, 27, 80, 142, 220, 172, 159, 244, 202, 237, 235>>}
  """
  @spec executor_address(keyword()) :: {:ok, binary()} | {:error, term()}
  def executor_address(opts \\ []), do: get(@executor_address, opts)

  @doc """
  Get the executor contract address. Raises on error.
  """
  @spec executor_address!(keyword()) :: binary()
  def executor_address!(opts \\ []), do: get!(@executor_address, opts)

  @doc """
  Get the reward ratio parameter.

  The reward ratio determines how block rewards are distributed.

  ## Examples

      iex> VeChain.Contracts.Params.reward_ratio(network: :mainnet)
      {:ok, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 15, 250, 200, 5, 187, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}
  """
  @spec reward_ratio(keyword()) :: {:ok, binary()} | {:error, term()}
  def reward_ratio(opts \\ []), do: get(@reward_ratio, opts)

  @doc """
  Get the reward ratio. Raises on error.
  """
  @spec reward_ratio!(keyword()) :: binary()
  def reward_ratio!(opts \\ []), do: get!(@reward_ratio, opts)

  @doc """
  Get the base gas price parameter.

  The base gas price is the minimum gas price for transactions.

  ## Examples

      iex> VeChain.Contracts.Params.base_gas_price(network: :mainnet)
      {:ok, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 141, 126, 164, 198, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}
  """
  @spec base_gas_price(keyword()) :: {:ok, binary()} | {:error, term()}
  def base_gas_price(opts \\ []), do: get(@base_gas_price, opts)

  @doc """
  Get the base gas price. Raises on error.
  """
  @spec base_gas_price!(keyword()) :: binary()
  def base_gas_price!(opts \\ []), do: get!(@base_gas_price, opts)

  @doc """
  Get the proposer endorsement threshold.

  ## Examples

      iex> VeChain.Contracts.Params.proposer_endorsement(network: :mainnet)
      {:ok, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}
  """
  @spec proposer_endorsement(keyword()) :: {:ok, binary()} | {:error, term()}
  def proposer_endorsement(opts \\ []), do: get(@proposer_endorsement, opts)

  @doc """
  Get the proposer endorsement threshold. Raises on error.
  """
  @spec proposer_endorsement!(keyword()) :: binary()
  def proposer_endorsement!(opts \\ []), do: get!(@proposer_endorsement, opts)

  @doc """
  Get the block interval parameter.

  The target time between blocks in seconds.

  ## Examples

      iex> VeChain.Contracts.Params.block_interval(network: :mainnet)
      {:ok, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10>>}
  """
  @spec block_interval(keyword()) :: {:ok, binary()} | {:error, term()}
  def block_interval(opts \\ []), do: get(@block_interval, opts)

  @doc """
  Get the block interval. Raises on error.
  """
  @spec block_interval!(keyword()) :: binary()
  def block_interval!(opts \\ []), do: get!(@block_interval, opts)
end
