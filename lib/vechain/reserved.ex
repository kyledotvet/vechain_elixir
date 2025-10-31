defmodule VeChain.Reserved do
  import Bitwise

  @moduledoc """
  VIP-191 reserved field handling for VeChain transactions.

  The reserved field is used to enable special transaction features,
  particularly VIP-191 fee delegation (designated gas payer).

  ## Structure

  The reserved field is an RLP list with the following structure:
  - First element: 32-bit unsigned integer (features bitmask)
  - Remaining elements: Reserved for future use (currently unused)

  ## Feature Flags

  - Bit 0 (0x01): VIP-191 fee delegation enabled

  ## Examples

      # Create empty reserved field (no features)
      reserved = Reserved.new()

      # Enable fee delegation
      reserved = Reserved.enable_fee_delegation(reserved)

      # Check if fee delegation is enabled
      Reserved.fee_delegation_enabled?(reserved)  # => true

      # Create with fee delegation enabled from start
      reserved = Reserved.new(fee_delegation: true)

  ## Encoding

  The reserved field is encoded as an RLP list:
  - Empty: `[]`
  - Fee delegation enabled: `[1]`
  - Future features: `[features_uint32, unused_bytes, ...]`

  ## Reference

  VIP-191 Specification:
  https://docs.vechain.org/core-concepts/transactions/meta-transaction-features/designated-gas-payer-vip-191
  """

  @type t :: %__MODULE__{
          features: non_neg_integer()
        }

  defstruct features: 0

  # Feature flag constants
  @feature_delegation 0x01

  @doc """
  Creates a new reserved field.

  ## Parameters

    * `opts` - Keyword list with:
      - `:fee_delegation` - Boolean, enable VIP-191 fee delegation (default: false)
      - `:features` - Integer, raw features bitmask (default: 0)

  ## Returns

  A new `Reserved` struct.

  ## Examples

      iex> Reserved.new()
      %Reserved{features: 0}

      iex> Reserved.new(fee_delegation: true)
      %Reserved{features: 1}

      iex> Reserved.new(features: 0x01)
      %Reserved{features: 1}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    features = opts[:features] || 0

    reserved = %__MODULE__{features: features}

    if opts[:fee_delegation] do
      enable_fee_delegation(reserved)
    else
      reserved
    end
  end

  @doc """
  Enables VIP-191 fee delegation.

  Sets the fee delegation feature flag in the reserved field.
  This allows a different address (gas payer) to pay for the transaction's gas.

  ## Parameters

    * `reserved` - Reserved struct

  ## Returns

  Updated `Reserved` struct with fee delegation enabled.

  ## Examples

      iex> alias VeChain.Reserved
      iex> reserved = Reserved.new()
      iex> reserved = Reserved.enable_fee_delegation(reserved)
      iex> reserved.features
      1

      iex> alias VeChain.Reserved
      iex> reserved = Reserved.new() |> Reserved.enable_fee_delegation()
      iex> Reserved.fee_delegation_enabled?(reserved)
      true
  """
  @spec enable_fee_delegation(t()) :: t()
  def enable_fee_delegation(%__MODULE__{features: features} = reserved) do
    %{reserved | features: features ||| @feature_delegation}
  end

  @doc """
  Disables VIP-191 fee delegation.

  Clears the fee delegation feature flag in the reserved field.

  ## Parameters

    * `reserved` - Reserved struct

  ## Returns

  Updated `Reserved` struct with fee delegation disabled.

  ## Examples

      iex> alias VeChain.Reserved
      iex> reserved = Reserved.new() |> Reserved.enable_fee_delegation()
      iex> reserved = Reserved.disable_fee_delegation(reserved)
      iex> reserved.features
      0

      iex> alias VeChain.Reserved
      iex> reserved = Reserved.new() |> Reserved.enable_fee_delegation() |> Reserved.disable_fee_delegation()
      iex> Reserved.fee_delegation_enabled?(reserved)
      false
  """
  @spec disable_fee_delegation(t()) :: t()
  def disable_fee_delegation(%__MODULE__{features: features} = reserved) do
    %{reserved | features: features &&& ~~~@feature_delegation}
  end

  @doc """
  Checks if VIP-191 fee delegation is enabled.

  ## Parameters

    * `reserved` - Reserved struct

  ## Returns

  Boolean indicating if fee delegation is enabled.

  ## Examples

      iex> reserved = Reserved.new()
      iex> Reserved.fee_delegation_enabled?(reserved)
      false

      iex> reserved = Reserved.new(fee_delegation: true)
      iex> Reserved.fee_delegation_enabled?(reserved)
      true
  """
  @spec fee_delegation_enabled?(t()) :: boolean()
  def fee_delegation_enabled?(%__MODULE__{features: features}) do
    (features &&& @feature_delegation) != 0
  end

  @doc """
  Encodes the reserved field for RLP encoding.

  Converts the reserved struct to a list suitable for RLP encoding.
  This is used internally by the transaction encoding process.

  ## Parameters

    * `reserved` - Reserved struct to encode

  ## Returns

  List suitable for RLP encoding:
  - Empty list `[]` if no features enabled
  - `[features]` if features are enabled

  ## Examples

      iex> reserved = Reserved.new()
      iex> Reserved.encode(reserved)
      []

      iex> reserved = Reserved.new(fee_delegation: true)
      iex> Reserved.encode(reserved)
      [1]
  """
  @spec encode(t()) :: list()
  def encode(%__MODULE__{features: 0}), do: []
  def encode(%__MODULE__{features: features}), do: [features]

  @doc """
  Decodes a reserved field from RLP-decoded list.

  Converts an RLP-decoded list back to a Reserved struct.
  This is used internally by the transaction decoding process.

  ## Parameters

    * `list` - RLP-decoded list (empty or `[features, ...]`)

  ## Returns

  A `Reserved` struct.

  ## Examples

      iex> Reserved.decode([])
      %Reserved{features: 0}

      iex> Reserved.decode([1])
      %Reserved{features: 1}

      iex> Reserved.decode([1, "unused"])
      %Reserved{features: 1}
  """
  @spec decode(list()) :: t()
  def decode([]), do: %__MODULE__{features: 0}

  def decode([features | _rest]) when is_integer(features) do
    %__MODULE__{features: features}
  end

  def decode([features_bin | _rest]) when is_binary(features_bin) do
    features = :binary.decode_unsigned(features_bin, :big)
    %__MODULE__{features: features}
  end

  @doc """
  Returns a human-readable description of enabled features.

  ## Parameters

    * `reserved` - Reserved struct

  ## Returns

  List of enabled feature names (strings).

  ## Examples

      iex> reserved = Reserved.new()
      iex> Reserved.describe(reserved)
      []

      iex> reserved = Reserved.new(fee_delegation: true)
      iex> Reserved.describe(reserved)
      ["VIP-191 Fee Delegation"]
  """
  @spec describe(t()) :: [String.t()]
  def describe(%__MODULE__{features: 0}), do: []

  def describe(%__MODULE__{} = reserved) do
    []
    |> maybe_add_feature(fee_delegation_enabled?(reserved), "VIP-191 Fee Delegation")
  end

  # Helper to conditionally add feature to list
  defp maybe_add_feature(list, true, name), do: [name | list]
  defp maybe_add_feature(list, false, _name), do: list
end
