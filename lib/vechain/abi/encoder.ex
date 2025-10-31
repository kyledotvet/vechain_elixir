defmodule VeChain.ABI.Encoder do
  @moduledoc """
  ABI encoding for function calls and constructor parameters.

  Wrapper around `ex_abi` library with VeChain-specific helpers.

  ## Examples

      # Encode transfer function call
      iex> VeChain.ABI.Encoder.encode_function_call(
      ...>   "transfer",
      ...>   ["address", "uint256"],
      ...>   ["0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000]
      ...> )
      {:ok, <<0xa9, 0x05, 0x9c, 0xbb, ...>>}
  """

  alias VeChain.ABI.FunctionSelector
  alias VeChain.Utils

  @doc """
  Encode a function call with parameters.

  ## Parameters

  - `function_name` - Function name (e.g., "transfer")
  - `types` - List of parameter types (e.g., ["address", "uint256"])
  - `values` - List of parameter values

  ## Examples

      iex> VeChain.ABI.Encoder.encode_function_call(
      ...>   "transfer",
      ...>   ["address", "uint256"],
      ...>   ["0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000]
      ...> )
      {:ok, <<0xa9, 0x05, 0x9c, 0xbb, ...>>}
  """
  @spec encode_function_call(String.t(), [String.t()], [any()]) ::
          {:ok, binary()} | {:error, term()}
  def encode_function_call(function_name, types, values)
      when is_binary(function_name) and is_list(types) and is_list(values) do
    try do
      # Generate function signature
      type_list = Enum.join(types, ",")
      signature = "#{function_name}(#{type_list})"

      # Get function selector (first 4 bytes)
      selector = FunctionSelector.encode(signature)

      # Normalize values (convert hex addresses to binaries)
      normalized_values = normalize_values(types, values)

      # Encode parameters
      encoded_params = ABI.encode(signature, normalized_values)

      # Combine selector + encoded params
      {:ok, selector <> encoded_params}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Encode a function call. Raises on error.
  """
  @spec encode_function_call!(String.t(), [String.t()], [any()]) :: binary()
  def encode_function_call!(function_name, types, values) do
    case encode_function_call(function_name, types, values) do
      {:ok, data} -> data
      {:error, error} -> raise VeChain.Error.EncodingError, message: "Failed to encode: #{inspect(error)}"
    end
  end

  @doc """
  Encode constructor parameters.

  ## Parameters

  - `types` - List of constructor parameter types
  - `values` - List of parameter values

  ## Examples

      iex> VeChain.ABI.Encoder.encode_constructor(
      ...>   ["uint256", "string"],
      ...>   [1000000, "MyToken"]
      ...> )
      {:ok, <<0x00, 0x0f, 0x42, 0x40, ...>>}
  """
  @spec encode_constructor([String.t()], [any()]) :: {:ok, binary()} | {:error, term()}
  def encode_constructor(types, values) when is_list(types) and is_list(values) do
    try do
      # Normalize values
      normalized_values = normalize_values(types, values)

      # Create a temporary function signature for encoding
      type_list = Enum.join(types, ",")
      signature = "constructor(#{type_list})"

      # Encode parameters (without selector)
      encoded = ABI.encode(signature, normalized_values)

      {:ok, encoded}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Encode constructor parameters. Raises on error.
  """
  @spec encode_constructor!([String.t()], [any()]) :: binary()
  def encode_constructor!(types, values) do
    case encode_constructor(types, values) do
      {:ok, data} -> data
      {:error, error} -> raise VeChain.Error.EncodingError, message: "Failed to encode constructor: #{inspect(error)}"
    end
  end

  @doc """
  Encode a single value according to its type.

  ## Examples

      iex> VeChain.ABI.Encoder.encode_value("uint256", 1000)
      {:ok, <<0x00, 0x00, ..., 0x03, 0xe8>>}

      iex> VeChain.ABI.Encoder.encode_value("address", "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed")
      {:ok, <<0x00, 0x00, ..., 0x75, 0x67, ...>>}
  """
  @spec encode_value(String.t(), any()) :: {:ok, binary()} | {:error, term()}
  def encode_value(type, value) when is_binary(type) do
    try do
      normalized = normalize_value(type, value)
      signature = "encode(#{type})"
      encoded = ABI.encode(signature, [normalized])
      {:ok, encoded}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Encode a single value. Raises on error.
  """
  @spec encode_value!(String.t(), any()) :: binary()
  def encode_value!(type, value) do
    case encode_value(type, value) do
      {:ok, data} -> data
      {:error, error} -> raise VeChain.Error.EncodingError, message: "Failed to encode value: #{inspect(error)}"
    end
  end

  # Private functions

  @spec normalize_values([String.t()], [any()]) :: [any()]
  defp normalize_values(types, values) do
    types
    |> Enum.zip(values)
    |> Enum.map(fn {type, value} -> normalize_value(type, value) end)
  end

  @spec normalize_value(String.t(), any()) :: any()
  defp normalize_value("address", value) when is_binary(value) do
    # Convert hex address string to 20-byte binary
    if String.starts_with?(value, "0x") do
      Utils.decode_address!(value)
    else
      value
    end
  end

  defp normalize_value("address[]", values) when is_list(values) do
    Enum.map(values, &normalize_value("address", &1))
  end

  defp normalize_value("bytes" <> _, value) when is_binary(value) do
    # Handle bytes, bytes32, etc.
    if String.starts_with?(value, "0x") do
      case Base.decode16(String.slice(value, 2..-1//1), case: :mixed) do
        {:ok, binary} -> binary
        :error -> value
      end
    else
      value
    end
  end

  defp normalize_value(_type, value), do: value
end
