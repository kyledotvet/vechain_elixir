defmodule VeChain.Transaction.Reserved do
  @moduledoc """
  TODO: Build this out properly
  """
  defstruct features: <<>>,
            unused: []

  @type t() :: %__MODULE__{
          features: binary(),
          unused: [binary()]
        }

  def cast([features | unused]) do
    %__MODULE__{
      features: features,
      unused: unused
    }
  end

  def cast([]) do
    %__MODULE__{}
  end

  def to_rlp_list(%__MODULE__{features: <<>>}) do
    []
  end

  defimpl ExRLP.Encode do
    alias VeChain.Transaction.Reserved

    def encode(%Reserved{features: features, unused: unused}, options \\ []) do
      features
      |> encode_features()
      |> Kernel.++(unused)
      |> ExRLP.encode(options)
    end

    defp encode_features(<<>>), do: []
    defp encode_features(0), do: []

    defp encode_features(features) when is_integer(features) do
      features
      |> :binary.encode_unsigned()
      |> encode_features()
    end

    defp encode_features(features) when is_binary(features) do
      [
        features
        |> :binary.decode_unsigned()
        |> Bitwise.band(1)
        |> :binary.encode_unsigned()
      ]
    end
  end

  defimpl Inspect do
    def inspect(reserved, opts) do
      %{
        reserved
        | features: :binary.decode_unsigned(reserved.features),
          unused: reserved.unused
      }
      |> Inspect.Any.inspect(opts)
    end
  end
end
