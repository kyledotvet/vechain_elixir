defmodule VeChain.Types do
  @moduledoc """
  Common type definitions for VeChain SDK.

  Follows elixir_VeChain pattern for type safety. These types define the
  public API format for addresses, hashes, and data.

  ## Type Definitions

  - `t_address/0` - Address as hex string with 0x prefix (42 characters)
  - `t_hash/0` - 32-byte hash as hex string with 0x prefix (66 characters)
  - `t_data/0` - Arbitrary length hex data with 0x prefix

  ## Usage

  These types are used throughout the public API to ensure consistent
  handling of hex-encoded values. Internally, the SDK converts these
  to binary format for RLP encoding and cryptographic operations.

  ## Examples

      # Address type
      address :: VeChain.Types.t_address()
      address = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"

      # Hash type
      tx_id :: VeChain.Types.t_hash()
      tx_id = "0xabcd1234..." # 32-byte hash

      # Data type
      data :: VeChain.Types.t_data()
      data = "0x1234abcd..." # Arbitrary length
  """

  @typedoc """
  VeChain address in its hex format with 0x or in its binary format
  <<_::336>> is 42 chars in hex including 0x prefix
  <<_::160>> is 20 bytes in binary format which is equivalent to above

  ## Examples
  - `"0xfC5A8BBFf0CFC616472772167024e7cd977F27f6"`
  - `<<252, 90, 139, 191, 240, 207, 198, 22, 71, 39, 114, 22, 112, 36, 231, 205, 151, 127, 39, 246>>`
  """
  @type t_address ::
          <<_::336>>
          | <<_::160>>

  @typedoc """
  keccak hash in its hex format with 0x or in its binary format

  ## Examples
  - `"0xd4288c8e733eb71a39fe2e8dd4912ce54d8d26d9874f30309b26b4b071260422"`
  - `<<1, 98, 102, 241, 90, 117, 57, 109, 162, 228, 62, 124, 209, 180, 218, 111, 203, 145, 103, 94, 169, 39, 220, 59, 55, 78, 181, 29, 103, 15, 212, 137>>`
  """
  @type t_hash ::
          <<_::528>>
          | <<_::256>>

  @typedoc """
  First 8 bytes of a referenced block id

  ## Examples
  - `0x0004f6cb730dbd90`
  - `<<0, 4, 246, 203, 115, 13, 189, 144>>`
  """
  @type t_block_ref ::
          <<_::144>>
          | <<_::64>>

  @typedoc """
  The transaction type in number, currently only supports:
  - 0 (Legacy Transaction)
  - 81 (DynamicFee Transaction)
  """
  @type tx_type :: 0 | 81

  @typedoc """
  Public key either in its uncompressed format (64 bytes MAY BE prefixed with 0x04) or its
  compressed format (32 bytes MUST BE prefixed with 0x02 or 0x03)

  It can be hex encoded but only with 0x prefix.

  Compressed public key MUST have a prefix.
  """
  @type t_pub_key ::
          <<_::520>>
          | <<_::512>>
          | <<_::264>>
          | <<_::1042>>
          | <<_::1026>>
          | <<_::530>>

  @typedoc """
  Private key either in its binary format (32 bytes) or its hex format with 0x prefix (66 characters)
  """
  @type t_private_key :: t_hash()

  @type t_bitsizes :: unquote(8..256//8 |> Enum.reduce(&{:|, [], [&1, &2]}))
  @type t_bytesizes :: unquote(1..32 |> Enum.reduce(&{:|, [], [&1, &2]}))
  @type t_evm_types ::
          {:uint, t_bitsizes()}
          | {:int, t_bitsizes()}
          | {:bytes, t_bytesizes()}
          | :bytes
          | :string
          | :address
          | {:array, t_evm_types()}
          | {:array, t_evm_types(), non_neg_integer()}
          | {:tuple, [t_evm_types()]}

  @valid_bitsize_range 8..256//8

  defguardp valid_bitsize(bitsize) when bitsize >= 8 and bitsize <= 256 and rem(bitsize, 8) == 0
  defguardp valid_bytesize(bytesize) when bytesize >= 1 and bytesize <= 32

  @doc """
  Returns the maximum possible value in the given type if supported.

  ## Examples

      iex> VeChain.Types.max({:uint, 8})
      255

      iex> VeChain.Types.max({:int, 8})
      127

      iex> VeChain.Types.max({:uint, 16})
      65535

      iex> VeChain.Types.max({:int, 16})
      32767

      iex> VeChain.Types.max({:uint, 128})
      340282366920938463463374607431768211455

      iex> VeChain.Types.max({:int, 128})
      170141183460469231731687303715884105727
  """
  def max(type)

  Enum.each(@valid_bitsize_range, fn bitsize ->
    {int_res, uint_res} =
      Enum.reduce(1..bitsize, {1, 1}, fn _bsize, {_, acc} -> {acc, 2 * acc} end)

    def max({:uint, unquote(bitsize)}) do
      unquote(uint_res - 1)
    end

    def max({:int, unquote(bitsize)}) do
      unquote(int_res - 1)
    end
  end)

  @doc """
  Returns the minimum possible value in the given type if supported.

  ## Examples

      iex> VeChain.Types.min({:uint, 8})
      0

      iex> VeChain.Types.min({:int, 8})
      -128

      iex> VeChain.Types.min({:uint, 16})
      0

      iex> VeChain.Types.min({:int, 16})
      -32768

      iex> VeChain.Types.min({:int, 24})
      -8388608

      iex> VeChain.Types.min({:int, 128})
      -170141183460469231731687303715884105728
  """
  def min(type)

  def min({:uint, bitsize}) when valid_bitsize(bitsize), do: 0

  Enum.each(@valid_bitsize_range, fn bitsize ->
    int_res = Enum.reduce(1..(bitsize - 1), 1, fn _bsize, acc -> 2 * acc end)

    def min({:int, unquote(bitsize)}) do
      unquote(-int_res)
    end
  end)

  @doc """
  Returns the default value in the given type if supported.

  ## Examples

      iex> VeChain.Types.default(:address)
      "0x0000000000000000000000000000000000000000"

      iex> VeChain.Types.default({:int, 32})
      0

      iex> VeChain.Types.default({:uint, 8})
      0

      iex> VeChain.Types.default({:int, 128})
      0

      iex> VeChain.Types.default(:string)
      ""

      iex> VeChain.Types.default(:bytes)
      ""

      iex> VeChain.Types.default({:bytes, 8})
      <<0, 0, 0, 0, 0, 0, 0, 0>>
  """
  def default({type, _}) when type in [:int, :uint], do: 0

  def default(:address), do: "0x0000000000000000000000000000000000000000"

  def default(type) when type in [:string, :bytes], do: ""

  def default({:bytes, size}) when valid_bytesize(size), do: <<0::size*8>>

  @doc """
  Checks if a given data matches a given solidity type

  ## Examples

      iex> VeChain.Types.matches_type?(false, :bool)
      true

      iex> VeChain.Types.matches_type?(200, {:uint, 8})
      true

      iex> VeChain.Types.matches_type?(400, {:uint, 8})
      false

      iex> VeChain.Types.matches_type?("0xdAC17F958D2ee523a2206206994597C13D831ec7", :address)
      true
  """
  @spec matches_type?(term(), t_evm_types()) :: boolean()
  def matches_type?(value, type)

  def matches_type?(value, {:uint, _bsize} = type),
    do: is_integer(value) and value >= 0 and value <= max(type)

  def matches_type?(value, {:int, _bsize} = type),
    do: is_integer(value) and value >= min(type) and value <= max(type)

  def matches_type?(value, :address) when is_binary(value) do
    byte_size(value) == 20 or (byte_size(value) == 42 and String.starts_with?(value, "0x"))
  end

  def matches_type?(_value, :address), do: false

  def matches_type?(value, :string), do: is_binary(value) and String.valid?(value)

  def matches_type?(value, :bytes), do: is_binary(value)

  def matches_type?(value, {:bytes, size}) when valid_bytesize(size),
    do: is_binary(value) && byte_size(value) == size

  def matches_type?(_value, {:bytes, size}),
    do: raise(ArgumentError, "Invalid size: #{inspect(size)} (must be 1 <= size <= 32)")

  def matches_type?(value, :bool), do: is_boolean(value)

  def matches_type?(values, {:array, sub_type, element_count}) do
    matches_type?(values, {:array, sub_type}) and Enum.count(values) == element_count
  end

  def matches_type?(values, {:array, sub_type}) do
    is_list(values) and Enum.all?(values, &matches_type?(&1, sub_type))
  end

  def matches_type?(values, {:tuple, sub_types}) do
    if is_tuple(values) and tuple_size(values) == Enum.count(sub_types) do
      Enum.zip(sub_types, Tuple.to_list(values))
      |> Enum.all?(fn {type, value} -> matches_type?(value, type) end)
    else
      false
    end
  end

  @doc """
  Validates and creates typed values to use with functions or events.

  Typed values are useful when there are multiple overloads of same function or event and you need
  to specify one of them to be used.

  Also raises with ArgumentError in case value does not match the given type.

  ## Examples

      iex> VeChain.Types.typed({:uint, 256}, 5)
      {:typed, {:uint, 256}, 5}

      iex> VeChain.Types.typed(:bytes, <<0, 1, 2>>)
      {:typed, :bytes, <<0, 1, 2>>}
  """
  @spec typed(term(), t_evm_types() | nil) :: {:typed, term(), term()} | no_return()
  def typed(type, nil), do: {:typed, type, nil}

  def typed(type, value) do
    if matches_type?(value, type) do
      {:typed, type, value}
    else
      raise ArgumentError, "Value #{inspect(value)} does not match type #{inspect(type)}"
    end
  end
end
