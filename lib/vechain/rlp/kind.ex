defmodule VeChain.RLP.Kind do
  @moduledoc """
  Behaviour for RLP kind implementations.

  Kinds define how to encode and decode specific data types in RLP format.
  Each kind implements validation and transformation logic for a specific data type.

  ## Types

  - ScalarKind: Module that implements this behaviour for primitive types
  - ArrayKind: `{:array, item_kind}` tuple for arrays with uniform element types
  - StructKind: List of `VeChain.RLP.Profile` structs for object fields

  ## Examples

      # ScalarKind implementation
      defmodule MyKind do
        @behaviour VeChain.RLP.Kind

        @impl true
        def data(data, context, opts) do
          # Validate and prepare data
          {:ok, fn -> encoded_bytes end}
        end

        @impl true
        def buffer(buffer, context, opts) do
          # Validate and decode buffer
          {:ok, fn -> decoded_value end}
        end
      end
  """

  @type context :: String.t()
  @type rlp_input :: binary() | list()
  @type encoder :: (() -> binary())
  @type decoder :: (() -> any())

  @doc """
  Validates and prepares data for encoding.

  This callback should:
  1. Validate the input data
  2. Transform it to the appropriate format
  3. Return a lazy encoder function

  ## Parameters

  - `data` - The data to encode (type depends on the kind)
  - `context` - Descriptive context string for error messages (e.g., "transaction.clauses[0].to")
  - `opts` - Keyword list of options (e.g., `[max_bytes: 32, bytes: 20]`)

  ## Returns

  - `{:ok, encoder}` - A lazy encoder function that returns the encoded binary
  - `{:error, reason}` - Validation or encoding error

  ## Examples

      iex> MyKind.data(1000, "value", [])
      {:ok, #Function<...>}

      iex> MyKind.data(-1, "value", [])
      {:error, "Expected non-negative integer in value"}
  """
  @callback data(data :: any(), context :: context(), opts :: keyword()) ::
              {:ok, encoder()} | {:error, term()}

  @doc """
  Validates and prepares buffer for decoding.

  This callback should:
  1. Validate the buffer format
  2. Transform it to the appropriate data type
  3. Return a lazy decoder function

  ## Parameters

  - `buffer` - The binary buffer to decode
  - `context` - Descriptive context string for error messages
  - `opts` - Keyword list of options

  ## Returns

  - `{:ok, decoder}` - A lazy decoder function that returns the decoded value
  - `{:error, reason}` - Validation or decoding error

  ## Examples

      iex> MyKind.buffer(<<0x03, 0xe8>>, "value", [])
      {:ok, #Function<...>}
  """
  @callback buffer(buffer :: binary(), context :: context(), opts :: keyword()) ::
              {:ok, decoder()} | {:error, term()}
end
