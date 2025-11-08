defmodule VeChain.RLP.Profile do
  @moduledoc """
  Defines the structure for RLP encoding/decoding profiles.

  A profile describes how to encode or decode a piece of data in RLP format.
  It consists of a name (for error messages and field mapping) and a kind
  (which defines the encoding/decoding logic).

  ## Profile Kinds

  There are three types of kinds:

  1. **ScalarKind** - A module implementing the `VeChain.RLP.Kind` behaviour
     for primitive types like numbers, hex strings, etc.

  2. **ArrayKind** - A tuple `{:array, item_kind}` describing arrays with
     uniform element types.

  3. **StructKind** - A list of `VeChain.RLP.Profile` structs describing
     object fields.

  ## Examples

      # Scalar profile for a numeric field
      %VeChain.RLP.Profile{
        name: "nonce",
        kind: VeChain.RLP.Kind.Numeric,
        opts: [max_bytes: 8]
      }

      # Array profile
      %VeChain.RLP.Profile{
        name: "clauses",
        kind: {:array, clause_profile}
      }

      # Struct profile
      %VeChain.RLP.Profile{
        name: "transaction",
        kind: [
          %VeChain.RLP.Profile{name: "chainTag", kind: VeChain.RLP.Kind.Numeric},
          %VeChain.RLP.Profile{name: "blockRef", kind: VeChain.RLP.Kind.HexBlob}
        ]
      }
  """

  @type kind ::
          module()
          | {:array, kind()}
          | [t()]

  @type t :: %__MODULE__{
          name: String.t(),
          kind: kind(),
          opts: keyword()
        }

  defstruct [:name, :kind, opts: []]

  @doc """
  Creates a new profile for a scalar field.

  ## Parameters

  - `name` - Field name (used in objects and error messages)
  - `kind_module` - Module implementing `VeChain.RLP.Kind` behaviour
  - `opts` - Keyword list of options passed to the kind (e.g., `[max_bytes: 32]`)

  ## Examples

      iex> VeChain.RLP.Profile.scalar("nonce", VeChain.RLP.Kind.Numeric, max_bytes: 8)
      %VeChain.RLP.Profile{
        name: "nonce",
        kind: VeChain.RLP.Kind.Numeric,
        opts: [max_bytes: 8]
      }
  """
  @spec scalar(String.t(), module(), keyword()) :: t()
  def scalar(name, kind_module, opts \\ []) do
    %__MODULE__{name: name, kind: kind_module, opts: opts}
  end

  @doc """
  Creates a new profile for an array field.

  ## Parameters

  - `name` - Field name
  - `item_kind` - Kind for array elements (can be scalar module, array, or struct)
  - `opts` - Keyword list of options

  ## Examples

      iex> item_profile = %VeChain.RLP.Profile{
      ...>   name: "item",
      ...>   kind: VeChain.RLP.Kind.Numeric
      ...> }
      iex> VeChain.RLP.Profile.array("numbers", item_profile.kind)
      %VeChain.RLP.Profile{
        name: "numbers",
        kind: {:array, VeChain.RLP.Kind.Numeric}
      }
  """
  @spec array(String.t(), kind(), keyword()) :: t()
  def array(name, item_kind, opts \\ []) do
    %__MODULE__{name: name, kind: {:array, item_kind}, opts: opts}
  end

  @doc """
  Creates a new profile for a struct field.

  ## Parameters

  - `name` - Field name
  - `field_profiles` - List of profiles describing the struct fields
  - `opts` - Keyword list of options

  ## Examples

      iex> VeChain.RLP.Profile.struct("clause", [
      ...>   VeChain.RLP.Profile.scalar("to", VeChain.RLP.Kind.HexBlob),
      ...>   VeChain.RLP.Profile.scalar("value", VeChain.RLP.Kind.Numeric)
      ...> ])
      %VeChain.RLP.Profile{
        name: "clause",
        kind: [
          %VeChain.RLP.Profile{name: "to", kind: VeChain.RLP.Kind.HexBlob},
          %VeChain.RLP.Profile{name: "value", kind: VeChain.RLP.Kind.Numeric}
        ]
      }
  """
  @spec struct(String.t(), [t()], keyword()) :: t()
  def struct(name, field_profiles, opts \\ []) when is_list(field_profiles) do
    %__MODULE__{name: name, kind: field_profiles, opts: opts}
  end
end
