defmodule VeChain.Transaction do
  @moduledoc """
  Transaction-related functions for handling VeChain transactions and struct initialization.

  This module provides functionality to:
  - Create and manipulate transaction structs
  - Encode transactions for network transmission
  - Handle different transaction types (legacy & EIP-1559)
  """
  alias VeChain.Transaction.Eip1559
  alias VeChain.Transaction.Clause
  alias VeChain.Transaction.Legacy
  alias VeChain.Utils
  alias VeChain.Configuration, as: Config
  alias VeChain.Transaction.Validation, as: Validate
  alias Ethers.Types

  @type t() :: Eip1559.t() | Legacy.t()

  @type id() :: binary() | nil
  @type chain_tag() :: <<_::8>>
  @type block_ref() :: <<_::64>>
  @type expiration() :: binary()
  @type gas() :: binary()
  @type depends_on() :: <<_::256>> | nil
  @type nonce() :: binary()
  @type signature() :: binary() | nil
  @type origin() :: Types.t_address() | nil
  @type delegator() :: Types.t_address() | nil
  @type clauses() :: [Clause.t()]

  @default_transaction_type :eip_1559

  @default_transaction_types [
    eip_1559: Eip1559,
    legacy: Legacy
  ]

  @gas_base_cost 5_000
  @gas_per_clause 16_000
  @gas_per_contract_creation_clause 48_000
  @gas_per_zero_byte 4
  @gas_per_non_zero_byte 68

  @spec new(keyword() | none()) :: t()
  def new(opts \\ []) do
    # If configuration is provided, use the network configuration provided, if not, default to configuration at the application level, application-level configuration will default to mainnet unless otherwise configured
    transaction_type = Keyword.get(opts, :type, @default_transaction_type)
    tx_module = Keyword.fetch!(@default_transaction_types, transaction_type)

    Keyword.get(opts, :network)
    |> Config.get_network()
    |> apply_block_ref(opts)
    |> apply_expiration(opts)
    |> apply_gas_fields(transaction_type, opts)
    |> apply_nonce(opts)
    |> Clause.parse_clauses(opts)
    |> tx_module.new()
  end

  def apply_block_ref(config, opts) do
    config
    |> Config.get_block_ref(opts)
    |> Validate.block_ref()
  end

  def apply_expiration(config, opts) do
    config
    |> Config.get_expiration(opts)
    |> Validate.expiration()
  end

  def apply_gas_fields(config, transaction_type, opts) do
    config
    |> Config.get_gas_fields(transaction_type, opts)
    |> Validate.gas_fields(transaction_type)
  end

  def apply_nonce(config, opts) do
    config
    |> Config.get_nonce(opts)
    |> Validate.nonce()
  end

  @spec cast(binary()) :: t()
  def cast(raw_tx) do
    raw_tx
    |> Utils.hex_decode!()
    |> typed_cast()
    |> calculate_hash()
  end

  def typed_cast(<<0x51::8, rlp_encoded_tx::binary>>) do
    rlp_encoded_tx
    |> ExRLP.decode()
    |> Eip1559.cast()
  end

  def typed_cast(rlp_encoded_tx) do
    rlp_encoded_tx
    |> ExRLP.decode()
    |> Legacy.cast()
  end

  def sign_as_sender(transaction, private_key) do
    # TODO: Validate that this is correct
    transaction
    |> sign_transaction_as_sender(private_key)
    |> calculate_hash()
  end

  # def sign_as_gas_payer(transaction, private_key) do
  #   # TODO: Implement fee delegation signing logic
  #   transaction
  #   |> sign_transaction_as_gas_payer(private_key)
  #   |> calculate_hash()
  # end

  @spec append_clause(t(), Clause.t()) :: t()
  def append_clause(transaction, clause) do
    %{transaction | clauses: transaction.clauses ++ [clause]}
    |> calculate_intrinsic_gas()
    |> calculate_hash()
  end

  @spec encode(t(), keyword()) :: binary()
  def encode(transaction, options \\ []), do: ExRLP.encode(transaction, options)

  @spec hex_encode(t(), keyword()) :: binary()
  def hex_encode(transaction, options \\ []) do
    transaction
    |> encode(options)
    |> Utils.hex_encode()
  end

  @spec hash(t(), Types.t_address() | nil) :: binary()
  def hash(transaction, sender \\ nil)

  def hash(transaction, nil) do
    transaction
    |> encode()
    |> Blake2.hash2b(32)
  end

  def hash(transaction, sender_address) do
    <<hash(transaction)::binary, sender_address::binary>>
    |> Blake2.hash2b(32)
  end

  def sign_transaction_as_sender(transaction, private_key) do
    %{transaction | signature: get_transaction_signature(transaction, private_key)}
  end

  # def sign_transaction_as_gas_payer(transaction, private_key) do
  #   # TODO: Implement fee delegation signing logic
  #   %{transaction | signature: get_transaction_signature(transaction, private_key)}
  # end

  def get_transaction_signature(transaction, private_key) do
    transaction
    |> hash()
    |> sign_transaction_hash(private_key)
  end

  def sign_transaction_hash(tx_hash, private_key) do
    {:ok, {signature, rec_id_int}} = ExSecp256k1.sign_compact(tx_hash, private_key)
    <<signature::binary, rec_id_int>>
  end

  def calculate_intrinsic_gas(transaction) do
    %{transaction | gas: calc_gas_for_clauses(transaction.clauses)}
  end

  def calc_gas_for_clauses(clauses) do
    Enum.reduce(clauses, @gas_base_cost, fn clause, acc ->
      acc + calc_gas_for_clause(clause)
    end)
  end

  def calc_gas_for_clause(%Clause{to: nil, data: data}) do
    # Contract creation clause
    @gas_per_contract_creation_clause + calculate_data_gas(data)
  end

  def calc_gas_for_clause(%Clause{data: data}) do
    # Regular clause
    @gas_per_clause + calculate_data_gas(data)
  end

  def calculate_data_gas(data, acc \\ 0)
  def calculate_data_gas(<<>>, acc), do: acc

  def calculate_data_gas(<<0, rest::binary>>, acc) do
    calculate_data_gas(rest, acc + @gas_per_zero_byte)
  end

  def calculate_data_gas(<<_non_zero_byte::binary-size(1), rest::binary>>, acc) do
    calculate_data_gas(rest, acc + @gas_per_non_zero_byte)
  end

  def calculate_hash(transaction) do
    # Recalculate transaction hash after modifications
    %{transaction | id: hash(transaction, transaction.origin)}
  end
end
