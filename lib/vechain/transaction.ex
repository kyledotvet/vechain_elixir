defmodule VeChain.Transaction do
  @moduledoc """
  VeChain transaction struct and composable transaction builder.

  Transactions follow a pipeline pattern similar to Req, with automatic step
  execution for standard workflows and manual control for advanced use cases.

  ## Standard Workflow

      # High-level: steps run automatically
      Transaction.new(network: :testnet)
      |> Transaction.add_clause(Clause.transfer_vet(to, amount))
      |> Transaction.run()              # Execute request steps
      |> Transaction.sign(private_key)  # Sign transaction
      |> Transaction.encode()           # RLP encode
      |> Transaction.broadcast()        # Send to network
      |> Transaction.await_receipt()    # Wait for confirmation

  ## Low-Level API

      # Manual control: no automatic steps
      Transaction.new(request_steps: [], response_steps: [])
      |> Transaction.put_chain_tag(0x27)
      |> Transaction.put_block_ref(block_ref)
      |> Transaction.put_expiration(32)
      |> Transaction.add_clause(clause)
      |> Transaction.calculate_intrinsic_gas()
      |> Transaction.put_gas(gas)
      |> Transaction.put_nonce(nonce)
      |> Transaction.sign(private_key)
      |> Transaction.encode()
      # ... manual broadcast

  ## Decoding Transactions

      # Decode raw transaction bytes
      {:ok, tx} = Transaction.decode(raw_bytes)

      # Inspect decoded transaction
      tx.clauses
      |> Enum.each(fn c ->
        IO.puts("To: " <> inspect(c.to))
        IO.puts("Value: " <> inspect(c.value))
      end)

  ## Telemetry Events

    * `[:vechain, :transaction, :sign]` - Transaction signed
    * `[:vechain, :transaction, :broadcast]` - Transaction broadcast
    * `[:vechain, :transaction, :confirmed]` - Transaction confirmed
  """

  alias VeChain.{Clause, Reserved, RLP, Utils, Client.Thor}
  alias VeChain.Crypto.{Blake2b, Secp256k1}
  alias VeChain.Transaction.Steps

  @type t :: %__MODULE__{
          chain_tag: byte() | nil,
          block_ref: non_neg_integer() | nil,
          expiration: non_neg_integer(),
          # Clause.t()
          clauses: [map()],
          gas_price_coef: byte(),
          gas: non_neg_integer() | nil,
          depends_on: binary() | nil,
          nonce: non_neg_integer() | nil,
          # Reserved.t()
          reserved: map(),
          signature: binary() | nil,
          network: :mainnet | :testnet | :solo | nil,
          private: map(),
          request_steps: keyword(),
          response_steps: keyword()
        }

  defstruct chain_tag: nil,
            block_ref: nil,
            expiration: 32,
            clauses: [],
            gas_price_coef: 0,
            gas: nil,
            depends_on: nil,
            nonce: nil,
            reserved: %Reserved{},
            signature: nil,
            network: nil,
            private: %{},
            request_steps: nil,
            response_steps: nil

  # ========================================
  # Phase 1 - Basic Transaction Building
  # ========================================

  @doc """
  Creates a new transaction.

  ## Parameters

    * `opts` - Keyword list with:
      - `:network` - Network identifier (:mainnet, :testnet, :solo)
      - `:chain_tag` - Chain tag byte (overrides network)
      - `:block_ref` - Block reference (8 bytes)
      - `:expiration` - Expiration in blocks (default: 32)
      - `:gas_price_coef` - Gas price coefficient (default: 0)
      - `:gas` - Gas limit
      - `:depends_on` - Transaction ID dependency (32 bytes)
      - `:nonce` - Transaction nonce (auto-generated if not provided)
      - `:reserved` - Reserved struct for features
      - `:clauses` - List of initial clauses

  ## Returns

  A new `Transaction` struct.

  ## Examples

      iex> Transaction.new(network: :testnet)
      %Transaction{chain_tag: 0x27, ...}

      iex> Transaction.new(chain_tag: 0x4a)
      %Transaction{chain_tag: 0x4a, ...}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    network = opts[:network]
    chain_tag = opts[:chain_tag] || network_to_chain_tag(network)

    %__MODULE__{
      chain_tag: chain_tag,
      block_ref: opts[:block_ref],
      expiration: opts[:expiration] || 32,
      clauses: opts[:clauses] || [],
      gas_price_coef: opts[:gas_price_coef] || 0,
      gas: opts[:gas],
      depends_on: opts[:depends_on],
      nonce: opts[:nonce],
      reserved: opts[:reserved] || %Reserved{},
      network: network
    }
  end

  @doc """
  Adds a clause to the transaction.

  ## Parameters

    * `tx` - Transaction struct
    * `clause` - Clause struct to add

  ## Returns

  Updated transaction with clause appended.

  ## Examples

      iex> tx = Transaction.new()
      iex> clause = Clause.transfer_vet("0x...", VeChain.Utils.vet(10))
      iex> tx = Transaction.add_clause(tx, clause)
      iex> length(tx.clauses)
      1
  """
  @spec add_clause(t(), Clause.t()) :: t()
  def add_clause(%__MODULE__{clauses: clauses} = tx, %Clause{} = clause) do
    %{tx | clauses: clauses ++ [clause]}
  end

  @doc """
  Sets the chain tag.

  ## Parameters

    * `tx` - Transaction struct
    * `chain_tag` - Chain tag byte

  ## Returns

  Updated transaction.
  """
  @spec put_chain_tag(t(), byte()) :: t()
  def put_chain_tag(%__MODULE__{} = tx, chain_tag) when is_integer(chain_tag) do
    %{tx | chain_tag: chain_tag}
  end

  @doc """
  Sets the block reference.

  ## Parameters

    * `tx` - Transaction struct
    * `block_ref` - Block reference (8 bytes)

  ## Returns

  Updated transaction.
  """
  @spec put_block_ref(t(), binary() | non_neg_integer()) :: t()
  def put_block_ref(%__MODULE__{} = tx, block_ref) do
    %{tx | block_ref: block_ref}
  end

  @doc """
  Sets the expiration.

  ## Parameters

    * `tx` - Transaction struct
    * `expiration` - Expiration in blocks

  ## Returns

  Updated transaction.
  """
  @spec put_expiration(t(), non_neg_integer()) :: t()
  def put_expiration(%__MODULE__{} = tx, expiration) when is_integer(expiration) do
    %{tx | expiration: expiration}
  end

  @doc """
  Sets the gas limit.

  ## Parameters

    * `tx` - Transaction struct
    * `gas` - Gas limit

  ## Returns

  Updated transaction.
  """
  @spec put_gas(t(), non_neg_integer()) :: t()
  def put_gas(%__MODULE__{} = tx, gas) when is_integer(gas) do
    %{tx | gas: gas}
  end

  @doc """
  Sets the gas price coefficient.

  ## Parameters

    * `tx` - Transaction struct
    * `coef` - Gas price coefficient (0-255)

  ## Returns

  Updated transaction.
  """
  @spec put_gas_price_coef(t(), byte()) :: t()
  def put_gas_price_coef(%__MODULE__{} = tx, coef) when is_integer(coef) do
    %{tx | gas_price_coef: coef}
  end

  @doc """
  Sets the transaction nonce.

  ## Parameters

    * `tx` - Transaction struct
    * `nonce` - Transaction nonce (8 bytes or integer)

  ## Returns

  Updated transaction.
  """
  @spec put_nonce(t(), non_neg_integer() | binary()) :: t()
  def put_nonce(%__MODULE__{} = tx, nonce) do
    %{tx | nonce: nonce}
  end

  @doc """
  Sets the depends_on field.

  ## Parameters

    * `tx` - Transaction struct
    * `tx_id` - Transaction ID dependency (32 bytes or hex string)

  ## Returns

  Updated transaction.
  """
  @spec put_depends_on(t(), binary() | String.t() | nil) :: t()
  def put_depends_on(%__MODULE__{} = tx, tx_id) do
    depends_on = normalize_hash(tx_id)
    %{tx | depends_on: depends_on}
  end

  @doc """
  Sets the reserved field.

  ## Parameters

    * `tx` - Transaction struct
    * `reserved` - Reserved struct

  ## Returns

  Updated transaction.
  """
  @spec put_reserved(t(), Reserved.t()) :: t()
  def put_reserved(%__MODULE__{} = tx, %Reserved{} = reserved) do
    %{tx | reserved: reserved}
  end

  @doc """
  Encodes the transaction to RLP format.

  Encodes the unsigned transaction (without signature) for signing or
  signed transaction (with signature) for broadcasting.

  ## Parameters

    * `tx` - Transaction struct

  ## Returns

  RLP-encoded transaction binary.

  ## Examples

      iex> tx = Transaction.new(chain_tag: 0x27)
      iex> |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      iex> encoded = Transaction.encode(tx)
      iex> is_binary(encoded)
      true
  """
  @spec encode(t()) :: binary()
  def encode(%__MODULE__{} = tx) do
    tx_list = [
      tx.chain_tag || 0,
      normalize_block_ref(tx.block_ref),
      tx.expiration,
      Enum.map(tx.clauses, &Clause.encode/1),
      tx.gas_price_coef,
      tx.gas || 0,
      tx.depends_on || "",
      tx.nonce || Utils.generate_nonce(),
      Reserved.encode(tx.reserved)
    ]

    tx_list =
      if tx.signature do
        tx_list ++ [tx.signature]
      else
        tx_list
      end

    RLP.encode(tx_list)
  end

  @doc """
  Decodes a transaction from RLP-encoded binary.

  ## Parameters

    * `data` - RLP-encoded transaction binary

  ## Returns

    * `{:ok, transaction}` - Decoded transaction struct
    * `{:error, reason}` - Decoding error

  ## Examples

      iex> alias VeChain.{Transaction, Clause}
      iex> tx = Transaction.new(chain_tag: 0x27) |> Transaction.put_block_ref(<<0,0,0,0,0,0,0,1>>) |> Transaction.add_clause(Clause.new()) |> Transaction.put_gas(21000)
      iex> {:ok, encoded} = Transaction.encode(tx)
      iex> {:ok, decoded} = Transaction.decode(encoded)
      iex> decoded.chain_tag == tx.chain_tag
      true
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, term()}
  def decode(data) when is_binary(data) do
    case RLP.decode(data) do
      [chain_tag, block_ref, expiration, clauses, gas_price_coef, gas, depends_on, nonce, reserved | rest] ->
        tx = %__MODULE__{
          chain_tag: to_integer(chain_tag),
          block_ref: block_ref,
          expiration: to_integer(expiration),
          clauses: Enum.map(clauses, &Clause.decode/1),
          gas_price_coef: to_integer(gas_price_coef),
          gas: to_integer(gas),
          depends_on: decode_optional(depends_on),
          nonce: to_integer(nonce),
          reserved: Reserved.decode(reserved)
        }

        tx =
          case rest do
            [signature] -> %{tx | signature: signature}
            [] -> tx
          end

        {:ok, tx}

      _ ->
        {:error, "Invalid transaction structure"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Gets the signing hash for the transaction.

  This is the Blake2b hash of the unsigned transaction that needs to be
  signed with the private key.

  ## Parameters

    * `tx` - Transaction struct

  ## Returns

  32-byte signing hash.

  ## Examples

      iex> tx = Transaction.new(chain_tag: 0x27)
      iex> hash = Transaction.get_signing_hash(tx)
      iex> byte_size(hash)
      32
  """
  @spec get_signing_hash(t()) :: binary()
  def get_signing_hash(%__MODULE__{} = tx) do
    # Encode without signature
    unsigned_tx = %{tx | signature: nil}
    unsigned_rlp = encode(unsigned_tx)
    Blake2b.hash(unsigned_rlp)
  end

  @doc """
  Signs the transaction with a private key.

  ## Parameters

    * `tx` - Transaction struct
    * `private_key` - 32-byte private key

  ## Returns

  Signed transaction struct.

  ## Examples

      iex> tx = Transaction.new(chain_tag: 0x27)
      iex> private_key = Secp256k1.generate_private_key()
      iex> signed_tx = Transaction.sign(tx, private_key)
      iex> byte_size(signed_tx.signature)
      65
  """
  @spec sign(t(), binary()) :: t()
  def sign(%__MODULE__{} = tx, <<private_key::binary-size(32)>>) do
    signing_hash = get_signing_hash(tx)
    signature = Secp256k1.sign(signing_hash, private_key)
    %{tx | signature: signature}
  end

  @doc """
  Gets the transaction ID.

  The transaction ID is the Blake2b hash of the signed transaction.
  Returns nil if the transaction is not signed.

  ## Parameters

    * `tx` - Transaction struct

  ## Returns

    * 32-byte transaction ID if signed
    * nil if not signed

  ## Examples

      iex> alias VeChain.Transaction
      iex> tx = Transaction.new()
      iex> Transaction.get_transaction_id(tx)
      nil
  """
  @spec get_transaction_id(t()) :: binary() | nil
  def get_transaction_id(%__MODULE__{signature: nil}), do: nil

  def get_transaction_id(%__MODULE__{} = tx) do
    signed_rlp = encode(tx)
    Blake2b.hash(signed_rlp)
  end

  @doc """
  Gets the transaction ID as a lowercase hex string.

  The transaction ID is the Blake2b hash of the signed transaction.
  Returns nil if the transaction is not signed.

  ## Parameters

    * `tx` - Transaction struct

  ## Returns

    * Lowercase hex string with "0x" prefix if signed
    * nil if not signed

  ## Examples

      iex> alias VeChain.Transaction
      iex> tx = Transaction.new()
      iex> Transaction.get_transaction_id_hex(tx)
      nil
  """
  @spec get_transaction_id_hex(t()) :: String.t() | nil
  def get_transaction_id_hex(%__MODULE__{} = tx) do
    case get_transaction_id(tx) do
      nil -> nil
      tx_id -> Utils.format_transaction_id(tx_id)
    end
  end

  @doc """
  Recovers the signer's address from a signed transaction.

  ## Parameters

    * `tx` - Signed transaction struct

  ## Returns

    * `{:ok, address}` - 20-byte signer address
    * `{:error, reason}` - If transaction is not signed or recovery fails

  ## Examples

      iex> alias VeChain.Transaction
      iex> tx = Transaction.new()
      iex> Transaction.recover_signer(tx)
      {:error, "Transaction not signed"}
  """
  @spec recover_signer(t()) :: {:ok, binary()} | {:error, term()}
  def recover_signer(%__MODULE__{signature: nil}), do: {:error, "Transaction not signed"}

  def recover_signer(%__MODULE__{signature: signature} = tx) do
    signing_hash = get_signing_hash(tx)
    Secp256k1.recover_address(signing_hash, signature)
  end

  # ========================================
  # Phase 2 - Transaction Pipeline
  # ========================================

  @doc """
  Runs the transaction preparation pipeline.

  Executes all request steps to prepare the transaction for signing:
    1. SetChainTag - Set network chain tag
    2. SetBlockRef - Get block reference from node
    3. SetExpiration - Set expiration window
    4. CalculateGas - Calculate intrinsic gas
    5. SetNonce - Generate deterministic nonce

  ## Parameters

    * `tx` - Transaction struct
    * `opts` - Pipeline options (passed to all steps):
      - `:client` - Thor client (required for SetBlockRef)
      - Additional step-specific options

  ## Returns

  Transaction ready for signing.

  ## Examples

      iex> client = Thor.client_for(:testnet)
      iex> tx = Transaction.new(network: :testnet)
      iex> |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      iex> |> Transaction.run(client: client)
      iex> tx.chain_tag
      0x27
  """
  @spec run(t(), keyword()) :: t()
  def run(%__MODULE__{} = tx, opts \\ []) do
    tx
    |> Steps.SetChainTag.call(opts)
    |> Steps.SetBlockRef.call(opts)
    |> Steps.SetExpiration.call(opts)
    |> Steps.CalculateGas.call(opts)
    |> Steps.SetNonce.call(opts)
  end

  @doc """
  Broadcasts a signed transaction to the blockchain.

  Wrapper around the Broadcast step for convenient API.

  ## Parameters

    * `tx` - Signed transaction struct
    * `opts` - Options:
      - `:client` - Thor client (required)

  ## Returns

  Transaction with broadcast response in private field.

  ## Examples

      # tx = Transaction.new(network: :testnet)
      # |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      # |> Transaction.run()
      # |> Transaction.sign(private_key)
      # |> Transaction.broadcast()
      # tx.private[:tx_id]
      # "0xabcd..."
  """
  @spec broadcast(t(), keyword()) :: t()
  def broadcast(%__MODULE__{} = tx, opts \\ []) do
    Steps.Broadcast.call(tx, opts)
  end

  @doc """
  Waits for transaction confirmation and returns the receipt.

  Wrapper around AwaitReceipt and DecodeReceipt steps.

  ## Parameters

    * `tx` - Broadcast transaction struct
    * `opts` - Options:
      - `:client` - Thor client (required)
      - `:timeout` - Maximum wait time in ms (default: 30,000)
      - `:interval` - Polling interval in ms (default: 1,000)
      - `:check_revert` - Whether to raise on revert (default: true)

  ## Returns

  Transaction with receipt in private field.

  ## Examples

      # tx = Transaction.new(network: :testnet)
      # |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      # |> Transaction.run()
      # |> Transaction.sign(private_key)
      # |> Transaction.broadcast()
      # |> Transaction.await_receipt()
      # tx.private[:receipt]["reverted"]
      # false
  """
  @spec await_receipt(t(), keyword()) :: t()
  def await_receipt(%__MODULE__{} = tx, opts \\ []) do
    tx
    |> Steps.AwaitReceipt.call(opts)
    |> Steps.DecodeReceipt.call(opts)
  end

  @doc """
  Co-signs a transaction with a gas payer's private key (VIP-191).

  Wrapper around the CoSign step for convenient API.

  ## Parameters

    * `tx` - Signed transaction struct
    * `opts` - Options:
      - `:gas_payer_key` - 32-byte gas payer private key (required if VIP-191 enabled)

  ## Returns

  Transaction with gas payer signature appended (130 bytes total).

  ## Examples

      # tx = Transaction.new(network: :testnet)
      # |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      # |> Transaction.enable_vip191()
      # |> Transaction.run()
      # |> Transaction.sign(private_key)
      # |> Transaction.co_sign(gas_payer_key)
      # byte_size(tx.signature)
      # 130
  """
  @spec co_sign(t(), keyword()) :: t()
  def co_sign(%__MODULE__{} = tx, opts \\ []) do
    Steps.CoSign.call(tx, opts)
  end

  @doc """
  Calculates intrinsic gas for the transaction.

  Wrapper around the CalculateGas step for manual use.

  ## Parameters

    * `tx` - Transaction struct

  ## Returns

  Transaction with gas set.

  ## Examples

      iex> tx = Transaction.new()
      iex> |> Transaction.add_clause(Clause.transfer_vet("0x...", 1000))
      iex> |> Transaction.calculate_intrinsic_gas()
      iex> tx.gas >= 21000
      true
  """
  @spec calculate_intrinsic_gas(t()) :: t()
  def calculate_intrinsic_gas(%__MODULE__{} = tx) do
    Steps.CalculateGas.call(tx, [])
  end

  # ========================================
  # Private Helpers
  # ========================================

  # Convert network symbol to chain tag
  defp network_to_chain_tag(:mainnet), do: 0x4A
  defp network_to_chain_tag(:testnet), do: 0x27
  defp network_to_chain_tag(:solo), do: 0xF6
  defp network_to_chain_tag(nil), do: nil

  # Normalize block reference to binary
  defp normalize_block_ref(nil), do: <<0::64>>
  defp normalize_block_ref(<<_::binary-size(8)>> = ref), do: ref
  defp normalize_block_ref(n) when is_integer(n), do: <<n::64>>

  # Normalize hash (32 bytes)
  defp normalize_hash(nil), do: nil
  defp normalize_hash(<<_::binary-size(32)>> = hash), do: hash

  defp normalize_hash("0x" <> hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, <<hash::binary-size(32)>>} -> hash
      _ -> nil
    end
  end

  defp normalize_hash(_), do: nil

  # Decode optional fields
  defp decode_optional(value) when value == "" or value == <<>>, do: nil
  defp decode_optional(value), do: value

  # Convert to integer
  defp to_integer(n) when is_integer(n), do: n
  defp to_integer(value) when value == "" or value == <<>>, do: 0

  defp to_integer(bin) when is_binary(bin) do
    :binary.decode_unsigned(bin, :big)
  end
end
