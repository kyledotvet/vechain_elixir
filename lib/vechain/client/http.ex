defmodule VeChain.Client.Http do
  @moduledoc """
  Thor RESTful API client for VeChainThor blockchain.

  Provides functions to interact with Thor nodes using the RESTful API.
  Built on top of the Req HTTP client library.

  ## API Reference

  https://docs.vechain.org/thor/learn/rest-api

  ## Examples

      # Create a client for testnet
      client = Thor.new("https://testnet.veblocks.net")

      # Get the latest block
      {:ok, block} = Thor.get_block(client, "best")

      # Post a transaction
      {:ok, response} = Thor.post_transaction(client, encoded_tx)

      # Get transaction receipt
      {:ok, receipt} = Thor.get_transaction_receipt(client, tx_id)
  """

  alias VeChain.Block
  alias VeChain.Network
  alias VeChain.Types
  alias VeChain.Utils
  alias VeChain.Transaction

  @type t :: Req.Request.t()

  @doc """
  Creates a new Thor API client.

  ## Parameters

    * `base_url` - Thor node base URL (e.g., "https://testnet.veblocks.net")
    * `opts` - Optional configuration (Req options)

  ## Returns

  A Req request struct configured for the Thor node.

  ## Examples

      iex> client = Thor.new("https://testnet.veblocks.net")
      iex> is_struct(client, Req.Request)
      true

      iex> client = Thor.new("https://mainnet.veblocks.net", receive_timeout: 30_000)
      iex> is_struct(client, Req.Request)
      true
  """
  @spec new(String.t(), keyword()) :: t()
  def new(base_url, opts \\ []) do
    Req.new([base_url: base_url] ++ opts)
    |> Req.Request.put_header("content-type", "application/json")
    |> Req.Request.put_header("accept", "application/json")
  end

  @doc """
  Creates a default Thor client based on application configuration.

  Reads the `:thor_node_url` from application config or uses testnet as default.

  ## Returns

  A Req request struct configured for the default Thor node.

  ## Examples

      iex> client = Thor.default_client()
      iex> is_struct(client, Req.Request)
      true
  """
  @spec default_client() :: t()
  def default_client do
    base_url = Application.get_env(:vechain, :thor_node_url, Network.default_node(:testnet))
    new(base_url)
  end

  @doc """
  Creates a client for a specific network.

  ## Parameters

    * `network` - Network identifier (`:mainnet`, `:testnet`, `:solo`)

  ## Returns

  A Req request struct configured for the network's default node.

  ## Examples

      iex> client = Thor.client_for(:mainnet)
      iex> is_struct(client, Req.Request)
      true
  """
  @spec client_for(:mainnet | :testnet | :solo) :: t()
  def client_for(network) when network in [:mainnet, :testnet, :solo] do
    new(Network.default_node(network))
  end

  @doc """
  Gets a block from the blockchain.

  ## Parameters

    * `client` - Thor client
    * `id` - Block identifier:
      - Block number (integer)
      - Block ID (hex string with "0x" prefix)
      - "best" - Latest block
      - "finalized" - Latest finalized block

  ## Returns

    * `{:ok, block}` - Block data as a map
    * `{:error, reason}` - Error details

  ## Examples

      iex> {:ok, block} = Thor.get_block(client, "best")
      iex> is_integer(block["number"])
      true

      iex> {:ok, block} = Thor.get_block(client, 12345)
      iex> block["number"] == 12345
      true
  """
  @spec get_block(t(), String.t() | non_neg_integer()) :: {:ok, map()} | {:error, term()}
  def get_block(client, id) do
    client
    |> Req.get(
      url: "/blocks/:block_id",
      path_params: [block_id: id]
    )
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Block.cast(body)}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets a block from the blockchain. Raises on error.

  ## Parameters

    * `client` - Thor client
    * `id` - Block identifier (see `get_block/2`)

  ## Returns

  Block data as a map.

  ## Examples

      iex> block = Thor.get_block!(client, "best")
      iex> is_integer(block["number"])
      true
  """
  @spec get_block!(t(), String.t()) :: map()
  def get_block!(client, id) do
    case get_block(client, id) do
      {:ok, block} -> block
      {:error, reason} -> raise "Failed to get block: #{inspect(reason)}"
    end
  end

  @doc """
  Posts a transaction to the blockchain.

  ## Parameters

    * `client` - Thor client
    * `raw_transaction` - RLP-encoded transaction (binary or hex string with "0x" prefix)

  ## Returns

    * `{:ok, response}` - Transaction submission response with "id" field
    * `{:error, reason}` - Error details

  ## Examples

      iex> {:ok, response} = Thor.post_transaction(client, "0x0123456789abcdef...")
  """
  @spec post_transaction(t(), binary() | String.t()) :: {:ok, map()} | {:error, term()}
  def post_transaction(client, encoded_transaction) do
    client
    |> Req.post(
      url: "/transactions",
      json: %{"raw" => encoded_transaction}
    )
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Posts a transaction to the blockchain. Raises on error.

  ## Parameters

    * `client` - Thor client
    * `raw_transaction` - RLP-encoded transaction (binary or hex string)

  ## Returns

  Transaction submission response with "id" field.

  ## Examples

      iex> encoded = Transaction.encode(signed_tx)
      iex> response = Thor.post_transaction!(client, encoded)
      iex> String.starts_with?(response["id"], "0x")
      true
  """
  @spec post_transaction!(t(), binary() | String.t()) :: map()
  def post_transaction!(client, raw_transaction) do
    case post_transaction(client, raw_transaction) do
      {:ok, response} -> response
      {:error, reason} -> raise "Failed to post transaction: #{inspect(reason)}"
    end
  end

  @doc """
  Gets a transaction by ID.

  ## Parameters

    * `client` - Thor client
    * `tx_id` - Transaction ID (hex string)

  ## Returns

    * `{:ok, transaction}` - Transaction data
    * `{:ok, nil}` - Transaction not found
    * `{:error, reason}` - Error details

  ## Examples

      iex> {:ok, tx} = Thor.get_transaction(client, "0xabcd...")
      iex> is_map(tx)
      true
  """
  @spec get_transaction(t(), Types.t_hash()) :: {:ok, map() | nil} | {:error, term()}
  def get_transaction(client, tx_id) do
    client
    |> Req.get(
      url: "/transactions/:tx_id",
      path_params: [tx_id: normalize_tx_id(tx_id)]
    )
    |> case do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, Transaction.Response.cast(body)}

      {:ok, %{status: 404}} ->
        {:ok, nil}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets a transaction by ID. Raises on error.

  Returns `nil` if transaction not found.
  """
  @spec get_transaction!(t(), String.t()) :: map() | nil
  def get_transaction!(client, tx_id) do
    case get_transaction(client, tx_id) do
      {:ok, tx} -> tx
      {:error, reason} -> raise "Failed to get transaction: #{inspect(reason)}"
    end
  end

  @doc """
  Gets a transaction receipt.

  Returns `nil` if the transaction is pending (not yet included in a block).

  ## Parameters

    * `client` - Thor client
    * `tx_id` - Transaction ID (32-byte hash as hex string with "0x" prefix)

  ## Returns

    * `{:ok, receipt}` - Transaction receipt as a map
    * `{:ok, nil}` - Transaction is pending
    * `{:error, reason}` - Error details

  ## Examples

      iex> {:ok, receipt} = Thor.get_transaction_receipt(client, "0xabcd...")
      iex> is_map(receipt)
      true

      iex> {:ok, nil} = Thor.get_transaction_receipt(client, "0xpending...")
      iex> # Transaction not yet mined
  """
  @spec get_transaction_receipt(t(), Types.t_hash()) :: {:ok, map() | nil} | {:error, term()}
  def get_transaction_receipt(client, tx_id) do
    client
    |> Req.get(
      url: "/transactions/:tx_id/receipt",
      path_params: [tx_id: normalize_tx_id(tx_id)]
    )
    |> case do
      {:ok, %{status: 200, body: nil}} ->
        {:ok, nil}

      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, Transaction.Receipt.cast(body)}

      {:ok, %{status: 404}} ->
        {:ok, nil}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets a transaction receipt. Raises on error.

  Returns `nil` if the transaction is pending.

  ## Parameters

    * `client` - Thor client
    * `tx_id` - Transaction ID (hex string with "0x" prefix)

  ## Returns

    * Transaction receipt as a map
    * `nil` if pending

  ## Examples

      iex> receipt = Thor.get_transaction_receipt!(client, "0xabcd...")
      iex> is_map(receipt)
      true
  """
  @spec get_transaction_receipt!(t(), String.t()) :: map() | nil
  def get_transaction_receipt!(client, tx_id) do
    case get_transaction_receipt(client, tx_id) do
      {:ok, receipt} -> receipt
      {:error, reason} -> raise "Failed to get transaction receipt: #{inspect(reason)}"
    end
  end

  @doc """
  Calls a contract function (read-only, does not create a transaction).

  This performs a simulated contract call without submitting a transaction.
  Useful for reading contract state or testing function calls.

  ## Parameters

    * `client` - Thor client
    * `contract_address` - Contract address (hex string)
    * `data` - Encoded function call data (hex string or binary)
    * `opts` - Options:
      - `:caller` - Caller address (optional, hex string)
      - `:value` - VET amount to send (optional, integer)
      - `:gas` - Gas limit (optional, integer)
      - `:gas_price` - Gas price (optional, string)
      - `:block` - Block to execute at (optional, "best", "finalized", or block ID)

  ## Returns

    * `{:ok, result}` - Call result with "data" and "reverted" fields
    * `{:error, reason}` - Error details

  ## Examples

      iex> data = "0x70a08231..." # balanceOf function call
      iex> {:ok, result} = Thor.call_contract(client, contract_addr, data)
      iex> result["data"]
      "0x0000000000000000000000000000000000000000000000000000000000000064"
  """
  @spec call_contract(t(), String.t(), binary() | String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def call_contract(client, contract_address, data, opts \\ []) do
    block = Keyword.get(opts, :block, "best")
    path = "/accounts/#{normalize_address(contract_address)}"

    clause = %{
      "to" => normalize_address(contract_address),
      "value" => Keyword.get(opts, :value, "0x0"),
      "data" => encode_hex(data)
    }

    body =
      %{
        "clauses" => [clause],
        "gas" => Keyword.get(opts, :gas),
        "gasPrice" => Keyword.get(opts, :gas_price)
      }
      |> maybe_add_caller(opts)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case Req.post(client, url: path, json: body, params: [revision: block]) do
      {:ok, %{status: 200, body: [result | _]}} ->
        {:ok, result}

      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Calls a contract function. Raises on error.

  See `call_contract/4` for details.

  ## Examples

      iex> result = Thor.call_contract!(client, contract_addr, data)
      iex> is_binary(result["data"])
      true
  """
  @spec call_contract!(t(), String.t(), binary() | String.t(), keyword()) :: map()
  def call_contract!(client, contract_address, data, opts \\ []) do
    case call_contract(client, contract_address, data, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "Failed to call contract: #{inspect(reason)}"
    end
  end

  @doc """
  Gets account information.

  ## Parameters

    * `client` - Thor client
    * `address` - Account address (hex string)
    * `opts` - Options:
      - `:block` - Block to query at (optional, "best", "finalized", or block ID)

  ## Returns

    * `{:ok, account}` - Account data with balance, energy, etc.
    * `{:error, reason}` - Error details

  ## Examples

      iex> {:ok, account} = Thor.get_account(client, "0x7567d83b...")
      iex> is_binary(account["balance"])
      true
  """
  @spec get_account(t(), Types.t_address(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_account(client, address, opts \\ []) do
    client
    |> Req.get(
      url: "/accounts/:address",
      path_params: [address: normalize_address(address)],
      params: [revision: Keyword.get(opts, :block)]
    )
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets account information. Raises on error.

  See `get_account/3` for details.
  """
  @spec get_account!(t(), String.t(), keyword()) :: map()
  def get_account!(client, address, opts \\ []) do
    case get_account(client, address, opts) do
      {:ok, account} -> account
      {:error, reason} -> raise "Failed to get account: #{inspect(reason)}"
    end
  end

  # ========================================
  # Private Helpers
  # ========================================

  # Normalize transaction ID
  defp normalize_tx_id("0x" <> _ = tx_id), do: tx_id
  defp normalize_tx_id(tx_id) when is_binary(tx_id), do: Utils.hex_encode(tx_id)

  # Normalize address for URL (ensures 0x prefix)
  defp normalize_address("0x" <> _ = address), do: address
  defp normalize_address(address) when is_binary(address), do: "0x" <> address

  # Encode binary to hex string with "0x" prefix
  defp encode_hex("0x" <> _ = hex), do: hex

  defp encode_hex(binary) when is_binary(binary) do
    "0x" <> Base.encode16(binary, case: :lower)
  end

  # Add caller to body if provided
  defp maybe_add_caller(body, opts) do
    case Keyword.get(opts, :caller) do
      nil -> body
      caller -> Map.put(body, "caller", normalize_address(caller))
    end
  end
end
