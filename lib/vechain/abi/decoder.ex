defmodule VeChain.ABI.Decoder do
  @moduledoc """
  ABI decoding for function returns and event logs.

  Wrapper around `ex_abi` library with VeChain-specific helpers.

  ## Examples

      # Decode balanceOf return value
      iex> VeChain.ABI.Decoder.decode_function_return(
      ...>   ["uint256"],
      ...>   "0x00000000000000000000000000000000000000000000000000000000000003e8"
      ...> )
      {:ok, [1000]}
  """

  import Bitwise
  alias VeChain.Utils

  @doc """
  Decode function return value.

  ## Parameters

  - `types` - List of return types (e.g., ["uint256"])
  - `data` - Hex string or binary return data

  ## Examples

      iex> VeChain.ABI.Decoder.decode_function_return(
      ...>   ["uint256"],
      ...>   "0x00000000000000000000000000000000000000000000000000000000000003e8"
      ...> )
      {:ok, [1000]}

      iex> VeChain.ABI.Decoder.decode_function_return(
      ...>   ["address"],
      ...>   return_data
      ...> )
      {:ok, ["0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"]}
  """
  @spec decode_function_return([String.t()], binary() | String.t()) ::
          {:ok, [any()]} | {:error, term()}
  def decode_function_return(types, data) when is_list(types) do
    try do
      # Convert hex string to binary if needed
      binary =
        if is_binary(data) and String.starts_with?(data, "0x") do
          case Base.decode16(String.slice(data, 2..-1//1), case: :mixed) do
            {:ok, bin} -> bin
            :error -> data
          end
        else
          data
        end

      # Create temporary function signature for decoding
      type_list = Enum.join(types, ",")
      signature = "decode(#{type_list})"

      # Decode data
      decoded = ABI.decode(signature, binary)

      # Post-process decoded values (convert addresses back to hex strings)
      formatted = format_decoded_values(types, decoded)

      {:ok, formatted}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Decode function return value. Raises on error.
  """
  @spec decode_function_return!([String.t()], binary() | String.t()) :: [any()]
  def decode_function_return!(types, data) do
    case decode_function_return(types, data) do
      {:ok, values} -> values
      {:error, error} -> raise VeChain.Error.EncodingError, message: "Failed to decode: #{inspect(error)}"
    end
  end

  @doc """
  Decode event log data.

  ## Parameters

  - `types` - List of event parameter types
  - `data` - Event data (hex string or binary)
  - `indexed_types` - List of indexed parameter types (optional)
  - `topics` - List of topics (optional)

  ## Examples

      iex> VeChain.ABI.Decoder.decode_event_log(
      ...>   ["address", "uint256"],
      ...>   event_data
      ...> )
      {:ok, ["0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000]}
  """
  @spec decode_event_log([String.t()], binary() | String.t(), [String.t()], [binary()]) ::
          {:ok, [any()]} | {:error, term()}
  def decode_event_log(types, data, indexed_types \\ [], topics \\ [])
      when is_list(types) and is_list(indexed_types) and is_list(topics) do
    try do
      # Convert hex string to binary if needed
      binary =
        if is_binary(data) and String.starts_with?(data, "0x") do
          case Base.decode16(String.slice(data, 2..-1//1), case: :mixed) do
            {:ok, bin} -> bin
            :error -> data
          end
        else
          data
        end

      # Decode non-indexed data
      type_list = Enum.join(types, ",")
      signature = "event(#{type_list})"
      decoded = ABI.decode(signature, binary)

      # Decode indexed parameters from topics (skip first topic which is event signature)
      indexed_decoded =
        if length(indexed_types) > 0 and length(topics) > 1 do
          indexed_topics = Enum.drop(topics, 1)

          indexed_types
          |> Enum.zip(indexed_topics)
          |> Enum.map(fn {type, topic} ->
            decode_indexed_topic(type, topic)
          end)
        else
          []
        end

      # Combine indexed and non-indexed values
      all_values = indexed_decoded ++ decoded

      # Format values (convert addresses to hex strings)
      formatted = format_decoded_values(indexed_types ++ types, all_values)

      {:ok, formatted}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Decode event log data. Raises on error.
  """
  @spec decode_event_log!([String.t()], binary() | String.t(), [String.t()], [binary()]) :: [any()]
  def decode_event_log!(types, data, indexed_types \\ [], topics \\ []) do
    case decode_event_log(types, data, indexed_types, topics) do
      {:ok, values} -> values
      {:error, error} -> raise VeChain.Error.EncodingError, message: "Failed to decode event: #{inspect(error)}"
    end
  end

  @doc """
  Decode a single value according to its type.

  ## Examples

      iex> VeChain.ABI.Decoder.decode_value("uint256", encoded_data)
      {:ok, 1000}

      iex> VeChain.ABI.Decoder.decode_value("address", encoded_data)
      {:ok, "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"}
  """
  @spec decode_value(String.t(), binary()) :: {:ok, any()} | {:error, term()}
  def decode_value(type, data) when is_binary(type) and is_binary(data) do
    try do
      signature = "decode(#{type})"
      [decoded] = ABI.decode(signature, data)

      formatted = format_decoded_value(type, decoded)
      {:ok, formatted}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Decode a single value. Raises on error.
  """
  @spec decode_value!(String.t(), binary()) :: any()
  def decode_value!(type, data) do
    case decode_value(type, data) do
      {:ok, value} -> value
      {:error, error} -> raise VeChain.Error.EncodingError, message: "Failed to decode value: #{inspect(error)}"
    end
  end

  # Private functions

  @spec decode_indexed_topic(String.t(), binary()) :: any()
  defp decode_indexed_topic(type, topic) do
    # Indexed parameters are padded to 32 bytes
    case type do
      "address" ->
        # Address is padded to 32 bytes, extract last 20 bytes
        binary_part(topic, 12, 20)

      "uint" <> _ ->
        # Decode as integer
        :binary.decode_unsigned(topic)

      "int" <> _ ->
        # Decode as signed integer
        decode_signed_int(topic)

      "bool" ->
        # Boolean
        topic != <<0::256>>

      _ ->
        # For complex types (strings, arrays, etc.), topic is hash
        topic
    end
  end

  @spec decode_signed_int(binary()) :: integer()
  defp decode_signed_int(<<sign::1, rest::bitstring>>) do
    unsigned = :binary.decode_unsigned(rest)

    if sign == 1 do
      # Negative number in two's complement
      -(bnot(unsigned) + 1)
    else
      unsigned
    end
  end

  @spec format_decoded_values([String.t()], [any()]) :: [any()]
  defp format_decoded_values(types, values) do
    types
    |> Enum.zip(values)
    |> Enum.map(fn {type, value} -> format_decoded_value(type, value) end)
  end

  @spec format_decoded_value(String.t(), any()) :: any()
  defp format_decoded_value("address", value) when is_binary(value) and byte_size(value) == 20 do
    # Convert 20-byte binary address to hex string
    Utils.encode_address!(value)
  end

  defp format_decoded_value("address[]", values) when is_list(values) do
    Enum.map(values, &format_decoded_value("address", &1))
  end

  defp format_decoded_value("bytes" <> _, value) when is_binary(value) do
    # Convert bytes to hex string
    "0x" <> Base.encode16(value, case: :lower)
  end

  defp format_decoded_value(_type, value), do: value
end
