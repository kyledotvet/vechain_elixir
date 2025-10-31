defmodule VeChain do
  @moduledoc """
  High-level convenience API for VeChain blockchain interactions.

  This module provides user-friendly functions for common VeChain operations:
  - Transferring VET and VTHO tokens
  - Deploying and calling smart contracts
  - Executing transactions with sensible defaults

  All functions accept hex string addresses (with or without "0x" prefix)
  and provide both tuple-returning and bang (!) versions.

  ## Examples

  ### Transfer VET

      VeChain.transfer_vet(
        to: "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
        amount: VeChain.Units.vet(10),
        private_key: private_key,
        network: :testnet
      )

  ### Execute custom transaction

      VeChain.execute(
        clauses: [
          VeChain.Clause.transfer_vet("0x...", VeChain.Units.vet(1)),
          VeChain.Clause.transfer_vet("0x...", VeChain.Units.vet(2))
        ],
        private_key: private_key,
        network: :mainnet
      )

  ## Options

  Most functions accept these common options:

  - `:network` - Network to use (`:mainnet`, `:testnet`, `:solo`), defaults to `:testnet`
  - `:chain_tag` - Override network's chain tag (optional)
  - `:block_ref` - Explicit block reference (optional, auto-fetched if not provided)
  - `:expiration` - Transaction expiration in blocks (default: 32)
  - `:gas` - Gas limit (auto-calculated if not provided)
  - `:gas_price_coef` - Gas price coefficient (default: 0)
  - `:depends_on` - Transaction dependency (optional)
  - `:nonce` - Explicit nonce (optional, auto-generated if not provided)
  - `:gas_payer_private_key` - VIP-191 gas payer key for fee delegation (optional)
  - `:await_receipt` - Wait for transaction confirmation (default: true)
  - `:timeout` - Receipt polling timeout in milliseconds (default: 60_000)
  - `:interval` - Receipt polling interval in milliseconds (default: 1_000)

  ## Error Handling

  Functions return `{:ok, result}` on success or `{:error, reason}` on failure.
  Bang versions (!) raise exceptions on errors.

      # Tuple version
      case VeChain.transfer_vet(to: address, amount: amount, private_key: key) do
        {:ok, receipt} -> IO.puts("Success!")
        {:error, reason} -> IO.puts("Error: \#{inspect(reason)}")
      end

      # Bang version
      receipt = VeChain.transfer_vet!(to: address, amount: amount, private_key: key)
  """

  alias VeChain.{Transaction, Clause, Error, Utils}

  require Logger

  @type address :: String.t()
  @type private_key :: binary()
  @type network :: :mainnet | :testnet | :solo
  @type amount :: non_neg_integer()
  @type receipt :: map()

  @type transfer_opts :: [
          to: address(),
          amount: amount(),
          private_key: private_key(),
          network: network(),
          chain_tag: byte(),
          block_ref: binary(),
          expiration: non_neg_integer(),
          gas: non_neg_integer(),
          gas_price_coef: byte(),
          depends_on: binary() | nil,
          nonce: non_neg_integer(),
          gas_payer_private_key: private_key(),
          await_receipt: boolean(),
          timeout: non_neg_integer(),
          interval: non_neg_integer()
        ]

  @type execute_opts :: [
          clauses: [Clause.t()],
          private_key: private_key(),
          network: network(),
          chain_tag: byte(),
          block_ref: binary(),
          expiration: non_neg_integer(),
          gas: non_neg_integer(),
          gas_price_coef: byte(),
          depends_on: binary() | nil,
          nonce: non_neg_integer(),
          gas_payer_private_key: private_key(),
          await_receipt: boolean(),
          timeout: non_neg_integer(),
          interval: non_neg_integer()
        ]

  # Telemetry events
  @telemetry_prefix [:vechain]

  @doc """
  Transfer VET tokens to an address.

  Returns `{:ok, receipt}` on success or `{:error, reason}` on failure.

  ## Options

  - `:to` (required) - Recipient address (hex string)
  - `:amount` (required) - Amount in wei (use `VeChain.Units.vet/1` for conversion)
  - `:private_key` (required) - Sender's private key (32 bytes)
  - Plus all common transaction options (see module documentation)

  ## Examples

      {:ok, receipt} = VeChain.transfer_vet(
        to: "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
        amount: VeChain.Units.vet(10),
        private_key: private_key,
        network: :testnet
      )

      # With fee delegation
      {:ok, receipt} = VeChain.transfer_vet(
        to: "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
        amount: VeChain.Units.vet(5),
        private_key: sender_key,
        gas_payer_private_key: payer_key,
        network: :mainnet
      )
  """
  @spec transfer_vet(transfer_opts()) :: {:ok, receipt()} | {:error, term()}
  def transfer_vet(opts) do
    with {:ok, to} <- validate_address(opts[:to], :to),
         {:ok, amount} <- validate_amount(opts[:amount]),
         {:ok, private_key} <- validate_private_key(opts[:private_key]) do
      clause = Clause.transfer_vet(to, amount)

      execute_opts =
        opts
        |> Keyword.put(:clauses, [clause])
        |> Keyword.put(:private_key, private_key)

      emit_telemetry(:transfer_vet, %{to: to, amount: amount})
      execute(execute_opts)
    end
  end

  @doc """
  Transfer VET tokens to an address. Raises on error.

  See `transfer_vet/1` for options and examples.
  """
  @spec transfer_vet!(transfer_opts()) :: receipt()
  def transfer_vet!(opts) do
    case transfer_vet(opts) do
      {:ok, receipt} -> receipt
      {:error, reason} -> raise Error.to_exception({:error, reason})
    end
  end

  @doc """
  Transfer VTHO tokens to an address.

  **Note**: This function requires Phase 4 (ABI & Contracts) to be implemented.
  It will be completed when the VTHO contract module is available.

  Returns `{:ok, receipt}` on success or `{:error, reason}` on failure.

  ## Options

  - `:to` (required) - Recipient address (hex string)
  - `:amount` (required) - Amount in wei (use `VeChain.Units.vtho/1` for conversion)
  - `:private_key` (required) - Sender's private key (32 bytes)
  - Plus all common transaction options (see module documentation)

  ## Examples

      {:ok, receipt} = VeChain.transfer_vtho(
        to: "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
        amount: VeChain.Units.vtho(100),
        private_key: private_key,
        network: :testnet
      )
  """
  @spec transfer_vtho(transfer_opts()) :: {:ok, receipt()} | {:error, term()}
  def transfer_vtho(_opts) do
    {:error, "VTHO transfer requires Phase 4 ABI implementation - coming soon"}
  end

  @doc """
  Transfer VTHO tokens to an address. Raises on error.

  See `transfer_vtho/1` for options and examples.
  """
  @spec transfer_vtho!(transfer_opts()) :: receipt()
  def transfer_vtho!(opts) do
    # {:ok, receipt} = transfer_vtho(opts)
    # receipt
    {:error, reason} = transfer_vtho(opts)
    raise Error.to_exception({:error, reason})
  end

  @doc """
  Call a smart contract function.

  **Note**: This function requires Phase 4 (ABI & Contracts) to be implemented.
  It will be completed when the ABI encoder/decoder modules are available.

  Returns `{:ok, result}` on success or `{:error, reason}` on failure.

  ## Options

  - `:contract_address` (required) - Contract address (hex string)
  - `:function` (required) - Function name (string)
  - `:params` (required) - Function parameters (list)
  - `:abi` (required) - Contract ABI (list of function definitions)
  - `:private_key` (required) - Caller's private key (32 bytes)
  - `:value` - VET to send with call (default: 0)
  - Plus all common transaction options (see module documentation)
  """
  @spec call_contract(keyword()) :: {:ok, term()} | {:error, term()}
  def call_contract(_opts) do
    {:error, "Contract calls require Phase 4 ABI implementation - coming soon"}
  end

  @doc """
  Call a smart contract function. Raises on error.

  See `call_contract/1` for options and examples.
  """
  @spec call_contract!(keyword()) :: term()
  def call_contract!(opts) do
    # {:ok, result} = call_contract(opts)
    # result
    {:error, reason} = call_contract(opts)
    raise Error.to_exception({:error, reason})
  end

  @doc """
  Deploy a smart contract.

  **Note**: This function requires Phase 4 (ABI & Contracts) to be implemented.
  It will be completed when the ABI encoder module is available.

  Returns `{:ok, {receipt, contract_address}}` on success or `{:error, reason}` on failure.

  ## Options

  - `:bytecode` (required) - Contract bytecode (hex string)
  - `:constructor_params` - Constructor parameters (default: [])
  - `:abi` - Contract ABI (optional, required if constructor has params)
  - `:private_key` (required) - Deployer's private key (32 bytes)
  - `:value` - VET to send with deployment (default: 0)
  - Plus all common transaction options (see module documentation)
  """
  @spec deploy_contract(keyword()) :: {:ok, {receipt(), address()}} | {:error, term()}
  def deploy_contract(_opts) do
    {:error, "Contract deployment requires Phase 4 ABI implementation - coming soon"}
  end

  @doc """
  Deploy a smart contract. Raises on error.

  See `deploy_contract/1` for options and examples.
  """
  @spec deploy_contract!(keyword()) :: {receipt(), address()}
  def deploy_contract!(opts) do
    # {:ok, result} = deploy_contract(opts)
    # result
    {:error, reason} = deploy_contract(opts)
    raise Error.to_exception({:error, reason})
  end

  @doc """
  Execute a transaction with custom clauses.

  This is the most flexible high-level function, allowing you to execute
  transactions with multiple clauses (atomic multi-operation transactions).

  Returns `{:ok, receipt}` on success or `{:error, reason}` on failure.

  ## Options

  - `:clauses` (required) - List of transaction clauses
  - `:private_key` (required) - Signer's private key (32 bytes)
  - Plus all common transaction options (see module documentation)

  ## Examples

      # Simple single-clause transaction
      {:ok, receipt} = VeChain.execute(
        clauses: [
          VeChain.Clause.transfer_vet("0x...", VeChain.Units.vet(10))
        ],
        private_key: private_key,
        network: :testnet
      )

      # Multi-clause atomic transaction
      {:ok, receipt} = VeChain.execute(
        clauses: [
          VeChain.Clause.transfer_vet("0xaaa...", VeChain.Units.vet(5)),
          VeChain.Clause.transfer_vet("0xbbb...", VeChain.Units.vet(3)),
          VeChain.Clause.transfer_vet("0xccc...", VeChain.Units.vet(2))
        ],
        private_key: private_key,
        network: :mainnet
      )

      # With fee delegation (VIP-191)
      {:ok, receipt} = VeChain.execute(
        clauses: [clause],
        private_key: sender_key,
        gas_payer_private_key: payer_key,
        network: :testnet
      )

      # Without waiting for receipt
      {:ok, tx_id} = VeChain.execute(
        clauses: [clause],
        private_key: private_key,
        await_receipt: false,
        network: :testnet
      )
  """
  @spec execute(execute_opts()) :: {:ok, receipt() | binary()} | {:error, term()}
  def execute(opts) do
    with {:ok, clauses} <- validate_clauses(opts[:clauses]),
         {:ok, private_key} <- validate_private_key(opts[:private_key]) do
      network = Keyword.get(opts, :network, :testnet)
      await_receipt = Keyword.get(opts, :await_receipt, true)

      # Build transaction
      tx_opts = build_transaction_opts(opts, network)
      tx = Transaction.new(tx_opts)

      # Add clauses
      tx =
        Enum.reduce(clauses, tx, fn clause, acc ->
          Transaction.add_clause(acc, clause)
        end)

      # Set optional overrides
      tx = apply_transaction_overrides(tx, opts)

      emit_telemetry(:execute_start, %{clauses: length(clauses), network: network})

      # Run transaction pipeline
      try do
        completed_tx =
          tx
          |> Transaction.run()
          |> Transaction.sign(private_key)
          |> maybe_co_sign(opts[:gas_payer_private_key])
          |> Transaction.broadcast()
          |> maybe_await_receipt(await_receipt, opts)

        # Extract result from transaction private field
        result = extract_result(completed_tx, await_receipt)
        emit_telemetry(:execute_success, %{})
        {:ok, result}
      rescue
        e ->
          emit_telemetry(:execute_error, %{})
          {:error, e}
      end
    end
  end

  @doc """
  Execute a transaction with custom clauses. Raises on error.

  See `execute/1` for options and examples.
  """
  @spec execute!(execute_opts()) :: receipt() | binary()
  def execute!(opts) do
    case execute(opts) do
      {:ok, result} -> result
      {:error, reason} -> raise Error.to_exception({:error, reason})
    end
  end

  # Private helper functions

  defp validate_address(nil, field) do
    {:error,
     %Error.InvalidAddress{message: "Address is required for field :#{field}"}}
  end

  defp validate_address(address, field) when is_binary(address) do
    if Utils.valid_address?(address) do
      {:ok, address}
    else
      {:error,
       %Error.InvalidAddress{
         message: "Invalid address for field :#{field}: #{inspect(address)}"
       }}
    end
  end

  defp validate_address(_address, field) do
    {:error,
     %Error.InvalidAddress{
       message: "Address must be a hex string for field :#{field}"
     }}
  end

  defp validate_amount(nil) do
    {:error, "Amount is required"}
  end

  defp validate_amount(amount) when is_integer(amount) and amount > 0 do
    {:ok, amount}
  end

  defp validate_amount(amount) when is_integer(amount) do
    {:error, "Amount must be greater than 0, got: #{amount}"}
  end

  defp validate_amount(amount) do
    {:error, "Amount must be an integer, got: #{inspect(amount)}"}
  end

  defp validate_private_key(nil) do
    {:error, %Error.InvalidPrivateKey{message: "Private key is required"}}
  end

  defp validate_private_key(key) when is_binary(key) and byte_size(key) == 32 do
    {:ok, key}
  end

  defp validate_private_key(key) when is_binary(key) do
    # Try to decode hex string
    case Utils.decode_hex(key) do
      {:ok, decoded} when byte_size(decoded) == 32 ->
        {:ok, decoded}

      _ ->
        {:error,
         %Error.InvalidPrivateKey{
           message: "Private key must be 32 bytes (64 hex characters)"
         }}
    end
  end

  defp validate_private_key(_key) do
    {:error,
     %Error.InvalidPrivateKey{
       message: "Private key must be a 32-byte binary or hex string"
     }}
  end

  defp validate_clauses(nil) do
    {:error, "Clauses are required"}
  end

  defp validate_clauses([]) do
    {:error, "At least one clause is required"}
  end

  defp validate_clauses(clauses) when is_list(clauses) do
    if Enum.all?(clauses, &is_struct(&1, Clause)) do
      {:ok, clauses}
    else
      {:error, "All clauses must be VeChain.Clause structs"}
    end
  end

  defp validate_clauses(_clauses) do
    {:error, "Clauses must be a list of VeChain.Clause structs"}
  end

  defp build_transaction_opts(opts, network) do
    base_opts = [network: network]

    # Add optional overrides if provided
    base_opts
    |> maybe_add_opt(opts, :chain_tag)
    |> maybe_add_opt(opts, :expiration)
    |> maybe_add_opt(opts, :gas_price_coef)
    |> maybe_add_opt(opts, :depends_on)
  end

  defp apply_transaction_overrides(tx, opts) do
    tx
    |> maybe_set_block_ref(opts[:block_ref])
    |> maybe_set_gas(opts[:gas])
    |> maybe_set_nonce(opts[:nonce])
  end

  defp maybe_add_opt(base_opts, opts, key) do
    case Keyword.get(opts, key) do
      nil -> base_opts
      value -> Keyword.put(base_opts, key, value)
    end
  end

  defp maybe_set_block_ref(tx, nil), do: tx
  defp maybe_set_block_ref(tx, block_ref), do: Transaction.put_block_ref(tx, block_ref)

  defp maybe_set_gas(tx, nil), do: tx
  defp maybe_set_gas(tx, gas), do: Transaction.put_gas(tx, gas)

  defp maybe_set_nonce(tx, nil), do: tx
  defp maybe_set_nonce(tx, nonce), do: Transaction.put_nonce(tx, nonce)

  defp maybe_co_sign(tx, nil), do: tx

  defp maybe_co_sign(tx, gas_payer_key) when is_binary(gas_payer_key) do
    Transaction.co_sign(tx, gas_payer_key)
  end

  defp maybe_await_receipt(tx, false, _opts) do
    # Don't wait for receipt, just return after broadcast
    tx
  end

  defp maybe_await_receipt(tx, true, opts) do
    timeout = Keyword.get(opts, :timeout, 60_000)
    interval = Keyword.get(opts, :interval, 1_000)

    Transaction.await_receipt(tx, timeout: timeout, interval: interval)
  end

  defp extract_result(tx, false) do
    # When not awaiting receipt, return transaction ID
    Transaction.get_transaction_id(tx)
  end

  defp extract_result(tx, true) do
    # When awaiting receipt, return the receipt from private field
    tx.private[:receipt] || raise "Receipt not found in transaction"
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(@telemetry_prefix ++ [event], %{}, metadata)
  end
end
