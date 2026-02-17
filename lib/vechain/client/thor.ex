defmodule VeChain.Client.Thor do
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
  alias Ethers.Types
  alias VeChain.Utils
  alias VeChain.Configuration

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
  def new(base_url \\ Configuration.get_thor_node_url(), opts \\ []) do
    [
      base_url: base_url,
      headers: [
        {"content-type", "application/json"},
        {"accept", "application/json"}
      ],
      retry: :transient,
      max_retries: 3,
      receive_timeout: 10_000
    ]
    |> Keyword.merge(opts)
    |> Req.new()
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
      iex> is_integer(block.number)
      true

      iex> {:ok, block} = Thor.get_block(client, 12345)
      iex> block.number == 12345
      true
  """
  @spec get_block(String.t() | non_neg_integer(), t()) :: {:ok, Block.t()} | {:error, term()}
  def get_block(id, client \\ new()) do
    client
    |> Req.get(
      url: "/blocks/:block_id",
      path_params: [block_id: id]
    )
    |> handle_response()
    |> cast_body(&Block.cast/1)
  end

  @doc """
  Gets a block from the blockchain. Raises on error.

  ## Parameters

    * `client` - Thor client
    * `id` - Block identifier (see `get_block/2`)

  ## Returns

  Block data as a `VeChain.Block` struct.

  ## Examples

      iex> block = Thor.get_block!(client, "best")
      iex> is_integer(block.number)
      true
  """
  @spec get_block!(String.t() | non_neg_integer(), t()) :: Block.t()
  def get_block!(id, client \\ new()) do
    client
    |> get_block(id)
    |> unwrap_or_raise!("Failed to get block")
  end

  @doc """
  Posts a transaction to the blockchain.

  ## Parameters

    * `client` - Thor client
    * `raw_transaction` - RLP-encoded transaction as a hex string with "0x" prefix.

  ## Returns

    * `{:ok, response}` - Transaction submission response with "id" field
    * `{:error, reason}` - Error details

  ## Examples

      iex> {:ok, response} = Thor.post_transaction(client, "0x0123456789abcdef...")
  """
  @spec post_transaction(String.t(), t()) :: {:ok, map()} | {:error, term()}
  def post_transaction(encoded_transaction, client \\ new()) do
    client
    |> Req.post(
      url: "/transactions",
      json: %{"raw" => encoded_transaction}
    )
    |> handle_response()
  end

  @doc """
  Posts a transaction to the blockchain. Raises on error.

  ## Parameters

    * `client` - Thor client
    * `raw_transaction` - RLP-encoded transaction as a hex string with "0x" prefix.

  ## Returns

  Transaction submission response with "id" field.

  ## Examples

      iex> encoded = VeChain.Transaction.encode(signed_tx)
      iex> response = Thor.post_transaction!(client, encoded)
      iex> String.starts_with?(response["id"], "0x")
      true
  """
  @spec post_transaction!(String.t(), t()) :: map()
  def post_transaction!(encoded_transaction, client \\ new()) do
    client
    |> post_transaction(encoded_transaction)
    |> unwrap_or_raise!("Failed to post transaction")
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
  @spec get_transaction(Types.t_hash(), t()) :: {:ok, map() | nil} | {:error, term()}
  def get_transaction(tx_id, client \\ new()) do
    client
    |> Req.get(
      url: "/transactions/:tx_id",
      path_params: [tx_id: normalize_tx_id(tx_id)]
    )
    |> handle_response()
  end

  @doc """
  Gets a transaction by ID. Raises on error.

  Returns `nil` if transaction not found.
  """
  @spec get_transaction!(String.t(), t()) :: map() | nil
  def get_transaction!(tx_id, client \\ new()) do
    client
    |> get_transaction(tx_id)
    |> unwrap_or_raise!("Failed to get transaction")
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
    |> handle_response()
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
  @spec get_transaction_receipt!(String.t(), t()) :: map() | nil
  def get_transaction_receipt!(tx_id, client \\ new()) do
    client
    |> get_transaction_receipt(tx_id)
    |> unwrap_or_raise!("Failed to get transaction receipt")
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
  @spec get_account(Types.t_address(), t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_account(address, client \\ new(), opts \\ []) do
    client
    |> Req.get(
      url: "/accounts/:address",
      path_params: [address: address],
      params: opts
    )
    |> handle_response()
  end

  @doc """
  Gets account information. Raises on error.

  See `get_account/3` for details.
  """
  @spec get_account!(String.t(), t(), keyword()) :: map()
  def get_account!(address, client \\ new(), opts \\ []) do
    address
    |> get_account(client, opts)
    |> unwrap_or_raise!("Failed to get account")
  end

  # ========================================
  # Private Helpers
  # ========================================

  # Handle standard HTTP responses with body transformation
  defp handle_response({:ok, %{status: 200, body: body}}) do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 404}}) do
    {:ok, nil}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end

  defp cast_body({:ok, body}, cast_fn) when is_function(cast_fn, 1), do: {:ok, cast_fn.(body)}
  defp cast_body(response, _cast_fn), do: response

  # Unwrap result tuple, raising on error
  defp unwrap_or_raise!({:ok, result}, _error_msg), do: result

  defp unwrap_or_raise!({:error, reason}, error_msg) do
    raise "#{error_msg}: #{inspect(reason)}"
  end

  # Normalize transaction ID
  defp normalize_tx_id("0x" <> _ = tx_id), do: tx_id
  defp normalize_tx_id(tx_id) when is_binary(tx_id), do: Utils.hex_encode(tx_id)
end
