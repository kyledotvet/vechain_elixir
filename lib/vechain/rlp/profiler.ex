defmodule VeChain.RLP.Profiler do
  @moduledoc """
  Handles profile-based RLP encoding and decoding.

  The Profiler provides a schema-driven approach to RLP encoding/decoding,
  using profiles that describe the structure and types of data. This ensures
  type safety and provides clear error messages.

  ## Examples

      # Simple numeric encoding
      profile = %VeChain.RLP.Profile{
        name: "value",
        kind: VeChain.RLP.Kind.Numeric,
        opts: [max_bytes: 32]
      }

      {:ok, rlp} = VeChain.RLP.Profiler.of_object(1000, profile)
      {:ok, decoded} = VeChain.RLP.Profiler.of_object_encoded(rlp.encoded, profile)

      # Struct encoding
      profile = %VeChain.RLP.Profile{
        name: "tx",
        kind: [
          %VeChain.RLP.Profile{name: "nonce", kind: VeChain.RLP.Kind.Numeric},
          %VeChain.RLP.Profile{name: "to", kind: VeChain.RLP.Kind.FixedHexBlob, opts: [bytes: 20]}
        ]
      }

      tx = %{"nonce" => 1, "to" => "0x" <> String.duplicate("ab", 20)}
      {:ok, rlp} = VeChain.RLP.Profiler.of_object(tx, profile)
  """

  alias VeChain.RLP.Profile

  defstruct [:encoded, :decoded, :profile]

  @type t :: %__MODULE__{
          encoded: binary(),
          decoded: ExRLP.t(),
          profile: Profile.t()
        }

  @doc """
  Encodes an object using the provided profile.

  ## Parameters

  - `obj` - The object to encode (map, list, or primitive value)
  - `profile` - The profile describing the data structure

  ## Returns

  - `{:ok, profiler}` - Profiler struct with encoded and decoded data
  - `{:error, reason}` - Encoding error

  ## Examples

      iex> profile = %VeChain.RLP.Profile{name: "val", kind: VeChain.RLP.Kind.Numeric}
      iex> {:ok, profiler} = VeChain.RLP.Profiler.of_object(1000, profile)
      iex> is_binary(profiler.encoded)
      true
  """
  @spec of_object(any(), Profile.t()) :: {:ok, t()} | {:error, term()}
  def of_object(obj, profile) do
    case pack_data(obj, profile, "") do
      {:ok, packed} ->
        encoded = ExRLP.encode(packed)
        {:ok, %__MODULE__{encoded: encoded, decoded: packed, profile: profile}}

      error ->
        error
    end
  end

  @doc """
  Decodes encoded data using the provided profile.

  ## Parameters

  - `encoded` - The RLP-encoded binary
  - `profile` - The profile describing the data structure

  ## Returns

  - `{:ok, profiler}` - Profiler struct with the object accessible via `.object`
  - `{:error, reason}` - Decoding error

  ## Examples

      iex> profile = %VeChain.RLP.Profile{name: "val", kind: VeChain.RLP.Kind.Numeric}
      iex> {:ok, profiler} = VeChain.RLP.Profiler.of_object(1000, profile)
      iex> {:ok, decoded_profiler} = VeChain.RLP.Profiler.of_object_encoded(profiler.encoded, profile)
      iex> decoded_profiler.object
      1000
  """
  @spec of_object_encoded(binary(), Profile.t()) :: {:ok, t()} | {:error, term()}
  def of_object_encoded(encoded, profile) when is_binary(encoded) do
    case ExRLP.decode(encoded) do
      {:ok, decoded} ->
        {:ok, %__MODULE__{encoded: encoded, decoded: decoded, profile: profile}}

      decoded when not is_tuple(decoded) ->
        {:ok, %__MODULE__{encoded: encoded, decoded: decoded, profile: profile}}

      {:error, reason} ->
        {:error, "RLP decode error: #{inspect(reason)}"}
    end
  end

  @doc """
  Returns the decoded unpacked object from a profiler struct.

  ## Examples

      iex> profile = %VeChain.RLP.Profile{name: "val", kind: VeChain.RLP.Kind.Numeric}
      iex> {:ok, profiler} = VeChain.RLP.Profiler.of_object(1000, profile)
      iex> {:ok, decoded} = VeChain.RLP.Profiler.of_object_encoded(profiler.encoded, profile)
      iex> decoded.object
      1000
  """
  def object(%__MODULE__{decoded: decoded, profile: profile}) do
    case unpack_data(decoded, profile, "") do
      {:ok, obj} -> obj
      {:error, reason} -> raise "Unpack error: #{reason}"
    end
  end

  @doc """
  Recursively packs data according to the profile.

  This converts an Elixir data structure into the format expected by RLP encoding.

  ## Parameters

  - `obj` - The object to pack
  - `profile` - The profile describing how to pack it
  - `context` - Context string for error messages (built recursively)

  ## Returns

  - `{:ok, packed}` - The packed data ready for RLP encoding
  - `{:error, reason}` - Packing error
  """
  @spec pack_data(any(), Profile.t(), String.t()) :: {:ok, any()} | {:error, term()}
  def pack_data(obj, %Profile{name: name, kind: kind, opts: opts}, context) do
    context = build_context(context, name)

    case kind do
      # ScalarKind: module that implements behaviour
      module when is_atom(module) and not is_nil(module) ->
        with {:ok, encoder} <- module.data(obj, context, opts) do
          {:ok, encoder.()}
        end

      # ArrayKind: {:array, item_kind}
      {:array, item_kind} when is_list(obj) ->
        pack_array(obj, item_kind, opts, context)

      {:array, _item_kind} ->
        {:error, "Expected array in #{context}, got: #{inspect(obj)}"}

      # StructKind: list of Profile structs
      profiles when is_list(profiles) ->
        pack_struct(obj, profiles, context)
    end
  end

  @doc """
  Recursively unpacks data according to the profile.

  This converts RLP-decoded data back into an Elixir data structure.

  ## Parameters

  - `packed` - The RLP-decoded data
  - `profile` - The profile describing how to unpack it
  - `context` - Context string for error messages

  ## Returns

  - `{:ok, unpacked}` - The unpacked Elixir data structure
  - `{:error, reason}` - Unpacking error
  """
  @spec unpack_data(any(), Profile.t(), String.t()) :: {:ok, any()} | {:error, term()}
  def unpack_data(packed, %Profile{name: name, kind: kind, opts: opts}, context) do
    context = build_context(context, name)

    case kind do
      # ScalarKind
      module when is_atom(module) and is_binary(packed) ->
        with {:ok, decoder} <- module.buffer(packed, context, opts) do
          {:ok, decoder.()}
        end

      # ArrayKind
      {:array, item_kind} when is_list(packed) ->
        unpack_array(packed, item_kind, opts, context)

      # StructKind
      profiles when is_list(profiles) and is_list(packed) ->
        unpack_struct(packed, profiles, context)

      _ ->
        {:error, "Type mismatch in #{context}: expected #{inspect(kind)}, got #{inspect(packed)}"}
    end
  end

  # Private functions

  defp build_context("", name), do: name
  defp build_context(context, name), do: "#{context}.#{name}"

  defp pack_array(items, item_kind, opts, context) do
    items
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {item, idx}, {:ok, acc} ->
      item_profile = %Profile{
        name: "[#{idx}]",
        kind: item_kind,
        opts: opts
      }

      case pack_data(item, item_profile, context) do
        {:ok, packed} -> {:cont, {:ok, [packed | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  end

  defp pack_struct(obj, profiles, context) when is_map(obj) do
    profiles
    |> Enum.reduce_while({:ok, []}, fn profile, {:ok, acc} ->
      # Support both string and atom keys
      field_data =
        Map.get(obj, profile.name) ||
          Map.get(obj, String.to_atom(profile.name))

      case pack_data(field_data, profile, context) do
        {:ok, packed} -> {:cont, {:ok, [packed | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  end

  defp pack_struct(obj, _profiles, context) do
    {:error, "Expected map in #{context}, got: #{inspect(obj)}"}
  end

  defp unpack_array(items, item_kind, opts, context) do
    items
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {item, idx}, {:ok, acc} ->
      item_profile = %Profile{
        name: "[#{idx}]",
        kind: item_kind,
        opts: opts
      }

      case unpack_data(item, item_profile, context) do
        {:ok, unpacked} -> {:cont, {:ok, [unpacked | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  end

  defp unpack_struct(packed_list, profiles, context) do
    if length(profiles) != length(packed_list) do
      {:error,
       "Structure field count mismatch in #{context}: expected #{length(profiles)}, got #{length(packed_list)}"}
    else
      Enum.zip(profiles, packed_list)
      |> Enum.reduce_while({:ok, %{}}, fn {profile, item}, {:ok, acc} ->
        case unpack_data(item, profile, context) do
          {:ok, unpacked} ->
            {:cont, {:ok, Map.put(acc, profile.name, unpacked)}}

          error ->
            {:halt, error}
        end
      end)
    end
  end
end
