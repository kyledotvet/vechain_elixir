defmodule VeChain.Contracts.Extension do
  @moduledoc """
  Extension contract interface.

  The Extension contract provides access to blockchain metadata and context
  information that is not available through standard EVM opcodes.

  The contract is deployed at a reserved address on all networks:
  `0x0000000000000000000000000000457874656e73696f6e` (hex encoding of "Extension")

  ## Available Functions

  - Block information (height, timestamp, ID, signer, etc.)
  - Transaction information (ID, origin, gas price, etc.)
  - Chain information (chain tag)

  ## Examples

      # Get current block number
      iex> VeChain.Contracts.Extension.block_number(network: :testnet)
      {:ok, 12345678}

      # Get current block timestamp
      iex> VeChain.Contracts.Extension.block_timestamp(network: :testnet)
      {:ok, 1234567890}
  """

  alias VeChain.{Client.Thor, ABI}

  # Extension contract address (same on all networks)
  # This is the hex encoding of "Extension"
  @extension_address "0x0000000000000000000000000000457874656e73696f6e"

  @doc """
  Get Extension contract address.

  The address is the same on all networks.

  ## Examples

      iex> VeChain.Contracts.Extension.address()
      "0x0000000000000000000000000000457874656e73696f6e"
  """
  @spec address() :: String.t()
  def address, do: @extension_address

  @doc """
  Get the current block number (height).

  ## Parameters

  - `opts` - Options (`:network`, `:client`, `:block`)

  ## Returns

  - `{:ok, block_number}` - Current block number (uint32)
  - `{:error, reason}` - Error details

  ## Examples

      iex> VeChain.Contracts.Extension.block_number(network: :testnet)
      {:ok, 12345678}
  """
  @spec block_number(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def block_number(opts \\ []) do
    call_contract("blockNumber", [], ["uint32"], opts)
  end

  @doc """
  Get the current block number. Raises on error.
  """
  @spec block_number!(keyword()) :: non_neg_integer()
  def block_number!(opts \\ []) do
    case block_number(opts) do
      {:ok, number} -> number
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get block number: #{inspect(error)}"
    end
  end

  @doc """
  Get the current block timestamp.

  ## Parameters

  - `opts` - Options (`:network`, `:client`, `:block`)

  ## Returns

  - `{:ok, timestamp}` - Block timestamp in seconds since Unix epoch (uint64)
  - `{:error, reason}` - Error details

  ## Examples

      iex> VeChain.Contracts.Extension.block_timestamp(network: :testnet)
      {:ok, 1234567890}
  """
  @spec block_timestamp(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def block_timestamp(opts \\ []) do
    call_contract("blockTimestamp", [], ["uint64"], opts)
  end

  @doc """
  Get the current block timestamp. Raises on error.
  """
  @spec block_timestamp!(keyword()) :: non_neg_integer()
  def block_timestamp!(opts \\ []) do
    case block_timestamp(opts) do
      {:ok, timestamp} -> timestamp
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get block timestamp: #{inspect(error)}"
    end
  end

  @doc """
  Get the current block ID.

  ## Parameters

  - `opts` - Options (`:network`, `:client`, `:block`)

  ## Returns

  - `{:ok, block_id}` - Block ID as hex string (bytes32)
  - `{:error, reason}` - Error details

  ## Examples

      iex> VeChain.Contracts.Extension.block_id(network: :testnet)
      {:ok, "0x00bc614e2c6e1a1e6e5f7b8f8e7e6d5c4b3a2918..."}
  """
  @spec block_id(keyword()) :: {:ok, String.t()} | {:error, term()}
  def block_id(opts \\ []) do
    call_contract("blockID", [], ["bytes32"], opts)
  end

  @doc """
  Get the current block ID. Raises on error.
  """
  @spec block_id!(keyword()) :: String.t()
  def block_id!(opts \\ []) do
    case block_id(opts) do
      {:ok, id} -> id
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get block ID: #{inspect(error)}"
    end
  end

  @doc """
  Get the current block signer (proposer) address.

  ## Parameters

  - `opts` - Options (`:network`, `:client`, `:block`)

  ## Returns

  - `{:ok, address}` - Block signer address as hex string
  - `{:error, reason}` - Error details

  ## Examples

      iex> VeChain.Contracts.Extension.block_signer(network: :testnet)
      {:ok, "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"}
  """
  @spec block_signer(keyword()) :: {:ok, String.t()} | {:error, term()}
  def block_signer(opts \\ []) do
    call_contract("blockSigner", [], ["address"], opts)
  end

  @doc """
  Get the current block signer. Raises on error.
  """
  @spec block_signer!(keyword()) :: String.t()
  def block_signer!(opts \\ []) do
    case block_signer(opts) do
      {:ok, signer} -> signer
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get block signer: #{inspect(error)}"
    end
  end

  @doc """
  Get the total score of the current block.

  The total score represents the cumulative difficulty/work of the chain.

  ## Parameters

  - `opts` - Options (`:network`, `:client`, `:block`)

  ## Returns

  - `{:ok, score}` - Total score (uint64)
  - `{:error, reason}` - Error details

  ## Examples

      iex> VeChain.Contracts.Extension.block_total_score(network: :testnet)
      {:ok, 987654321}
  """
  @spec block_total_score(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def block_total_score(opts \\ []) do
    call_contract("blockTotalScore", [], ["uint64"], opts)
  end

  @doc """
  Get the total score. Raises on error.
  """
  @spec block_total_score!(keyword()) :: non_neg_integer()
  def block_total_score!(opts \\ []) do
    case block_total_score(opts) do
      {:ok, score} -> score
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get block total score: #{inspect(error)}"
    end
  end

  @doc """
  Get the current transaction ID.

  Note: This only works when called within a transaction context
  (not via eth_call/contract read).

  ## Parameters

  - `opts` - Options (`:network`, `:client`)

  ## Returns

  - `{:ok, tx_id}` - Transaction ID as hex string (bytes32)
  - `{:error, reason}` - Error details

  ## Examples

      # Only available within transaction execution
      iex> VeChain.Contracts.Extension.tx_id(network: :testnet)
      {:ok, "0xabcd1234..."}
  """
  @spec tx_id(keyword()) :: {:ok, String.t()} | {:error, term()}
  def tx_id(opts \\ []) do
    call_contract("txID", [], ["bytes32"], opts)
  end

  @doc """
  Get the transaction ID. Raises on error.
  """
  @spec tx_id!(keyword()) :: String.t()
  def tx_id!(opts \\ []) do
    case tx_id(opts) do
      {:ok, id} -> id
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get tx ID: #{inspect(error)}"
    end
  end

  @doc """
  Get the transaction origin address (original sender).

  Note: This only works when called within a transaction context.

  ## Parameters

  - `opts` - Options (`:network`, `:client`)

  ## Returns

  - `{:ok, address}` - Origin address as hex string
  - `{:error, reason}` - Error details

  ## Examples

      iex> VeChain.Contracts.Extension.tx_origin(network: :testnet)
      {:ok, "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"}
  """
  @spec tx_origin(keyword()) :: {:ok, String.t()} | {:error, term()}
  def tx_origin(opts \\ []) do
    call_contract("txOrigin", [], ["address"], opts)
  end

  @doc """
  Get the transaction origin. Raises on error.
  """
  @spec tx_origin!(keyword()) :: String.t()
  def tx_origin!(opts \\ []) do
    case tx_origin(opts) do
      {:ok, origin} -> origin
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get tx origin: #{inspect(error)}"
    end
  end

  @doc """
  Get the transaction expiration height.

  Note: This only works when called within a transaction context.

  ## Parameters

  - `opts` - Options (`:network`, `:client`)

  ## Returns

  - `{:ok, expiration}` - Expiration block height (uint32)
  - `{:error, reason}` - Error details

  ## Examples

      iex> VeChain.Contracts.Extension.tx_expiration(network: :testnet)
      {:ok, 12345710}
  """
  @spec tx_expiration(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def tx_expiration(opts \\ []) do
    call_contract("txExpiration", [], ["uint32"], opts)
  end

  @doc """
  Get the transaction expiration. Raises on error.
  """
  @spec tx_expiration!(keyword()) :: non_neg_integer()
  def tx_expiration!(opts \\ []) do
    case tx_expiration(opts) do
      {:ok, expiration} -> expiration
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get tx expiration: #{inspect(error)}"
    end
  end

  @doc """
  Get the transaction gas price.

  Note: This only works when called within a transaction context.

  ## Parameters

  - `opts` - Options (`:network`, `:client`)

  ## Returns

  - `{:ok, gas_price}` - Gas price in wei (uint256)
  - `{:error, reason}` - Error details

  ## Examples

      iex> VeChain.Contracts.Extension.tx_gas_price(network: :testnet)
      {:ok, 1000000000000000}
  """
  @spec tx_gas_price(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def tx_gas_price(opts \\ []) do
    call_contract("txGasPrice", [], ["uint256"], opts)
  end

  @doc """
  Get the transaction gas price. Raises on error.
  """
  @spec tx_gas_price!(keyword()) :: non_neg_integer()
  def tx_gas_price!(opts \\ []) do
    case tx_gas_price(opts) do
      {:ok, gas_price} -> gas_price
      {:error, error} -> raise VeChain.Error.ContractError, message: "Failed to get tx gas price: #{inspect(error)}"
    end
  end

  # Private helper functions

  @spec call_contract(String.t(), [String.t()], [String.t()], keyword()) ::
          {:ok, any()} | {:error, term()}
  defp call_contract(function_name, input_types, output_types, opts) do
    with {:ok, data} <- ABI.Encoder.encode_function_call(function_name, input_types, []),
         client <- Keyword.get(opts, :client) || Thor.default_client(),
         {:ok, result} <- Thor.call_contract(client, @extension_address, data, opts),
         {:ok, [decoded]} <- ABI.Decoder.decode_function_return(output_types, result["data"]) do
      {:ok, decoded}
    end
  end
end
