defmodule VeChain.Transaction.Reserved do
  @moduledoc """
  TODO: Build this out properly
  """
  defstruct features: 0,
            unused: []

  def to_rlp_list(%__MODULE__{features: 0}) do
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

    defp encode_features(0), do: []

    defp encode_features(features) do
      [
        features
        |> Bitwise.band(1)
        |> :binary.encode_unsigned()
      ]
    end
  end
end
