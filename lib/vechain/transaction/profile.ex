defmodule VeChain.Transaction.Profile do
  @moduledoc """
  RLP encoding/decoding profiles for VeChain transactions.

  This module defines the profile-based schemas for encoding and decoding
  VeChain transactions using the RLP profiler system.

  ## Usage

      # Encoding a transaction
      tx = %{
        "chainTag" => 1,
        "blockRef" => "0x00000000aabbccdd",
        "expiration" => 1000,
        "clauses" => [%{"to" => "0x...", "value" => 0, "data" => "0x"}],
        "gasPriceCoef" => 0,
        "gas" => 21000,
        "dependsOn" => nil,
        "nonce" => 12345678,
        "reserved" => []
      }

      {:ok, profiler} = VeChain.RLP.Profiler.of_object(tx, transaction_profile())
      encoded_tx = profiler.encoded

      # Decoding a transaction
      {:ok, profiler} = VeChain.RLP.Profiler.of_object_encoded(encoded_tx, transaction_profile())
      decoded_tx = VeChain.RLP.Profiler.object(profiler)
  """

  alias VeChain.RLP.Profile
  alias VeChain.RLP.Kind.{Numeric, HexBlob, CompactFixedHexBlob, OptionalFixedHexBlob, Buffer}

  @doc """
  Returns the RLP profile for a VeChain transaction clause.

  A clause represents a single operation in a transaction and consists of:
  - `to`: The recipient address (20 bytes, optional for contract creation)
  - `value`: The amount of VET to transfer (integer)
  - `data`: Contract call data or deployment bytecode (hex blob)

  ## Examples

      iex> clause = %{
      ...>   "to" => "0x" <> String.duplicate("ab", 20),
      ...>   "value" => 1000,
      ...>   "data" => "0x"
      ...> }
      iex> profile = VeChain.Transaction.Profile.clause_profile()
      iex> {:ok, profiler} = VeChain.RLP.Profiler.of_object(clause, %VeChain.RLP.Profile{name: "clause", kind: profile})
      iex> is_binary(profiler.encoded)
      true
  """
  @spec clause_profile() :: [Profile.t()]
  def clause_profile do
    [
      %Profile{
        name: "to",
        kind: OptionalFixedHexBlob,
        opts: [bytes: 20]
      },
      %Profile{
        name: "value",
        kind: Numeric,
        opts: [max_bytes: 32]
      },
      %Profile{
        name: "data",
        kind: HexBlob
      }
    ]
  end

  @doc """
  Returns the RLP profile for a complete VeChain transaction (unsigned).

  A VeChain transaction consists of:
  - `chainTag`: Network identifier (1 byte)
  - `blockRef`: Reference block for transaction expiration (8 bytes, compact)
  - `expiration`: Number of blocks until expiration (4 bytes max)
  - `clauses`: Array of transaction clauses
  - `gasPriceCoef`: Gas price coefficient (1 byte)
  - `gas`: Gas limit (8 bytes max)
  - `dependsOn`: Transaction dependency (32 bytes, optional)
  - `nonce`: Random nonce for uniqueness (8 bytes max)
  - `reserved`: Reserved fields for future use (array)

  ## Examples

      iex> tx = %{
      ...>   "chainTag" => 1,
      ...>   "blockRef" => "0x00000000aabbccdd",
      ...>   "expiration" => 1000,
      ...>   "clauses" => [],
      ...>   "gasPriceCoef" => 0,
      ...>   "gas" => 21000,
      ...>   "dependsOn" => nil,
      ...>   "nonce" => 12345678,
      ...>   "reserved" => []
      ...> }
      iex> profile = VeChain.Transaction.Profile.transaction_profile()
      iex> {:ok, profiler} = VeChain.RLP.Profiler.of_object(tx, profile)
      iex> is_binary(profiler.encoded)
      true
  """
  @spec transaction_profile() :: Profile.t()
  def transaction_profile do
    %Profile{
      name: "transaction",
      kind: [
        %Profile{
          name: "chainTag",
          kind: Numeric,
          opts: [max_bytes: 1]
        },
        %Profile{
          name: "blockRef",
          kind: CompactFixedHexBlob,
          opts: [bytes: 8]
        },
        %Profile{
          name: "expiration",
          kind: Numeric,
          opts: [max_bytes: 4]
        },
        %Profile{
          name: "clauses",
          kind: {:array, clause_profile()}
        },
        %Profile{
          name: "gasPriceCoef",
          kind: Numeric,
          opts: [max_bytes: 1]
        },
        %Profile{
          name: "gas",
          kind: Numeric,
          opts: [max_bytes: 8]
        },
        %Profile{
          name: "dependsOn",
          kind: OptionalFixedHexBlob,
          opts: [bytes: 32]
        },
        %Profile{
          name: "nonce",
          kind: Numeric,
          opts: [max_bytes: 8]
        },
        %Profile{
          name: "reserved",
          kind: {:array, Buffer}
        }
      ]
    }
  end

  @doc """
  Returns the RLP profile for a signed VeChain transaction (Legacy).

  A signed transaction includes all fields from an unsigned transaction plus:
  - `signature`: The ECDSA signature (65 bytes: r + s + v)

  ## Examples

      iex> tx = %{
      ...>   "chainTag" => 1,
      ...>   "blockRef" => "0x00000000aabbccdd",
      ...>   "expiration" => 1000,
      ...>   "clauses" => [],
      ...>   "gasPriceCoef" => 0,
      ...>   "gas" => 21000,
      ...>   "dependsOn" => nil,
      ...>   "nonce" => 12345678,
      ...>   "reserved" => [],
      ...>   "signature" => "0x" <> String.duplicate("ab", 65)
      ...> }
      iex> profile = VeChain.Transaction.Profile.signed_transaction_profile()
      iex> {:ok, profiler} = VeChain.RLP.Profiler.of_object(tx, profile)
      iex> is_binary(profiler.encoded)
      true
  """
  @spec signed_transaction_profile() :: Profile.t()
  def signed_transaction_profile do
    %Profile{
      name: "signed_transaction",
      kind:
        transaction_profile().kind ++
          [
            %Profile{
              name: "signature",
              kind: HexBlob
            }
          ]
    }
  end

  @doc """
  Returns the RLP profile for an EIP-1559 VeChain transaction (unsigned).

  An EIP-1559 transaction replaces gasPriceCoef with:
  - `maxPriorityFeePerGas`: Maximum priority fee per gas (32 bytes)
  - `maxFeePerGas`: Maximum fee per gas (32 bytes)

  ## Examples

      iex> tx = %{
      ...>   "chainTag" => 1,
      ...>   "blockRef" => "0x00000000aabbccdd",
      ...>   "expiration" => 1000,
      ...>   "clauses" => [],
      ...>   "maxPriorityFeePerGas" => 1000,
      ...>   "maxFeePerGas" => 2000,
      ...>   "gas" => 21000,
      ...>   "dependsOn" => nil,
      ...>   "nonce" => 12345678,
      ...>   "reserved" => []
      ...> }
      iex> profile = VeChain.Transaction.Profile.eip1559_transaction_profile()
      iex> {:ok, profiler} = VeChain.RLP.Profiler.of_object(tx, profile)
      iex> is_binary(profiler.encoded)
      true
  """
  @spec eip1559_transaction_profile() :: Profile.t()
  def eip1559_transaction_profile do
    %Profile{
      name: "eip1559_transaction",
      kind: [
        %Profile{
          name: "chainTag",
          kind: Numeric,
          opts: [max_bytes: 1]
        },
        %Profile{
          name: "blockRef",
          kind: CompactFixedHexBlob,
          opts: [bytes: 8]
        },
        %Profile{
          name: "expiration",
          kind: Numeric,
          opts: [max_bytes: 4]
        },
        %Profile{
          name: "clauses",
          kind: {:array, clause_profile()}
        },
        %Profile{
          name: "maxPriorityFeePerGas",
          kind: Numeric,
          opts: [max_bytes: 32]
        },
        %Profile{
          name: "maxFeePerGas",
          kind: Numeric,
          opts: [max_bytes: 32]
        },
        %Profile{
          name: "gas",
          kind: Numeric,
          opts: [max_bytes: 8]
        },
        %Profile{
          name: "dependsOn",
          kind: OptionalFixedHexBlob,
          opts: [bytes: 32]
        },
        %Profile{
          name: "nonce",
          kind: Numeric,
          opts: [max_bytes: 8]
        },
        %Profile{
          name: "reserved",
          kind: {:array, Buffer}
        }
      ]
    }
  end

  @doc """
  Returns the RLP profile for a signed EIP-1559 VeChain transaction.

  A signed EIP-1559 transaction includes all fields from an unsigned EIP-1559 transaction plus:
  - `signature`: The ECDSA signature (65 bytes: r + s + v)

  ## Examples

      iex> tx = %{
      ...>   "chainTag" => 1,
      ...>   "blockRef" => "0x00000000aabbccdd",
      ...>   "expiration" => 1000,
      ...>   "clauses" => [],
      ...>   "maxPriorityFeePerGas" => 1000,
      ...>   "maxFeePerGas" => 2000,
      ...>   "gas" => 21000,
      ...>   "dependsOn" => nil,
      ...>   "nonce" => 12345678,
      ...>   "reserved" => [],
      ...>   "signature" => "0x" <> String.duplicate("ab", 65)
      ...> }
      iex> profile = VeChain.Transaction.Profile.signed_eip1559_transaction_profile()
      iex> {:ok, profiler} = VeChain.RLP.Profiler.of_object(tx, profile)
      iex> is_binary(profiler.encoded)
      true
  """
  @spec signed_eip1559_transaction_profile() :: Profile.t()
  def signed_eip1559_transaction_profile do
    %Profile{
      name: "signed_eip1559_transaction",
      kind:
        eip1559_transaction_profile().kind ++
          [
            %Profile{
              name: "signature",
              kind: HexBlob
            }
          ]
    }
  end

  @doc """
  Encodes a VeChain transaction using the appropriate profile.

  Automatically detects transaction type (Legacy vs EIP-1559) and whether
  the transaction is signed or unsigned based on the presence of fields.

  For EIP-1559 transactions, the encoded data is prefixed with 0x51.

  ## Parameters

  - `tx` - Transaction map with string or atom keys

  ## Returns

  - `{:ok, encoded}` - RLP-encoded transaction bytes
  - `{:error, reason}` - Encoding error

  ## Examples

      iex> tx = %{
      ...>   chainTag: 1,
      ...>   blockRef: "0x00000000aabbccdd",
      ...>   expiration: 1000,
      ...>   clauses: [],
      ...>   gasPriceCoef: 0,
      ...>   gas: 21000,
      ...>   dependsOn: nil,
      ...>   nonce: 12345678,
      ...>   reserved: []
      ...> }
      iex> {:ok, encoded} = VeChain.Transaction.Profile.encode(tx)
      iex> is_binary(encoded)
      true

      iex> tx_eip = %{
      ...>   chainTag: 1,
      ...>   blockRef: "0x00000000aabbccdd",
      ...>   expiration: 1000,
      ...>   clauses: [],
      ...>   maxPriorityFeePerGas: 1000,
      ...>   maxFeePerGas: 2000,
      ...>   gas: 21000,
      ...>   dependsOn: nil,
      ...>   nonce: 12345678,
      ...>   reserved: []
      ...> }
      iex> {:ok, encoded} = VeChain.Transaction.Profile.encode(tx_eip)
      iex> <<prefix, _rest::binary>> = encoded
      iex> prefix
      0x51
  """
  @spec encode(map()) :: {:ok, binary()} | {:error, term()}
  def encode(tx) when is_map(tx) do
    has_signature = Map.has_key?(tx, "signature") or Map.has_key?(tx, :signature)
    is_eip1559 =
      Map.has_key?(tx, "maxFeePerGas") or Map.has_key?(tx, :maxFeePerGas) or
        Map.has_key?(tx, "maxPriorityFeePerGas") or Map.has_key?(tx, :maxPriorityFeePerGas)

    profile =
      case {is_eip1559, has_signature} do
        {true, true} -> signed_eip1559_transaction_profile()
        {true, false} -> eip1559_transaction_profile()
        {false, true} -> signed_transaction_profile()
        {false, false} -> transaction_profile()
      end

    case VeChain.RLP.Profiler.of_object(tx, profile) do
      {:ok, profiler} ->
        encoded =
          if is_eip1559 do
            <<0x51, profiler.encoded::binary>>
          else
            profiler.encoded
          end

        {:ok, encoded}

      error ->
        error
    end
  end

  @doc """
  Decodes a VeChain transaction from RLP-encoded bytes.

  Automatically detects transaction type by checking for 0x51 prefix (EIP-1559)
  and field count (signed vs unsigned).

  ## Parameters

  - `encoded` - RLP-encoded transaction bytes

  ## Returns

  - `{:ok, tx}` - Decoded transaction map
  - `{:error, reason}` - Decoding error

  ## Examples

      iex> tx = %{chainTag: 1, blockRef: "0x00000000aabbccdd", expiration: 1000, clauses: [], gasPriceCoef: 0, gas: 21000, dependsOn: nil, nonce: 12345678, reserved: []}
      iex> {:ok, encoded} = VeChain.Transaction.Profile.encode(tx)
      iex> {:ok, decoded} = VeChain.Transaction.Profile.decode(encoded)
      iex> decoded["chainTag"]
      1

      iex> tx_eip = %{chainTag: 1, blockRef: "0x00000000aabbccdd", expiration: 1000, clauses: [], maxPriorityFeePerGas: 1000, maxFeePerGas: 2000, gas: 21000, dependsOn: nil, nonce: 12345678, reserved: []}
      iex> {:ok, encoded} = VeChain.Transaction.Profile.encode(tx_eip)
      iex> {:ok, decoded} = VeChain.Transaction.Profile.decode(encoded)
      iex> decoded["maxFeePerGas"]
      2000
  """
  @spec decode(binary()) :: {:ok, map()} | {:error, term()}
  def decode(encoded) when is_binary(encoded) do
    # Check for EIP-1559 prefix
    {is_eip1559, rlp_data} =
      case encoded do
        <<0x51, rest::binary>> -> {true, rest}
        _ -> {false, encoded}
      end

    # Decode the RLP to check the structure length
    case ExRLP.decode(rlp_data) do
      {:ok, decoded_list} when is_list(decoded_list) ->
        decode_by_type_and_length(rlp_data, is_eip1559, length(decoded_list))

      decoded_list when is_list(decoded_list) ->
        decode_by_type_and_length(rlp_data, is_eip1559, length(decoded_list))

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Invalid RLP structure"}
    end
  end

  # Private helper to decode based on type and structure length
  defp decode_by_type_and_length(encoded, false, 10) do
    # 10 fields = signed Legacy transaction
    case VeChain.RLP.Profiler.of_object_encoded(encoded, signed_transaction_profile()) do
      {:ok, profiler} ->
        {:ok, VeChain.RLP.Profiler.object(profiler)}

      error ->
        error
    end
  end

  defp decode_by_type_and_length(encoded, false, 9) do
    # 9 fields = unsigned Legacy transaction
    case VeChain.RLP.Profiler.of_object_encoded(encoded, transaction_profile()) do
      {:ok, profiler} ->
        {:ok, VeChain.RLP.Profiler.object(profiler)}

      error ->
        error
    end
  end

  defp decode_by_type_and_length(encoded, true, 10) do
    # 10 fields = signed EIP-1559 transaction
    case VeChain.RLP.Profiler.of_object_encoded(encoded, signed_eip1559_transaction_profile()) do
      {:ok, profiler} ->
        {:ok, VeChain.RLP.Profiler.object(profiler)}

      error ->
        error
    end
  end

  defp decode_by_type_and_length(encoded, true, 9) do
    # 9 fields = unsigned EIP-1559 transaction
    case VeChain.RLP.Profiler.of_object_encoded(encoded, eip1559_transaction_profile()) do
      {:ok, profiler} ->
        {:ok, VeChain.RLP.Profiler.object(profiler)}

      error ->
        error
    end
  end

  defp decode_by_type_and_length(_encoded, is_eip1559, count) do
    type_str = if is_eip1559, do: "EIP-1559", else: "Legacy"

    {:error,
     "Invalid #{type_str} transaction structure: expected 9 or 10 fields, got #{count}"}
  end
end
