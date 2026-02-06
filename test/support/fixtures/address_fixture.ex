defmodule VeChain.AddressFixture do
  @moduledoc """
  Test helpers for creating addresses.
  """
  def random_address do
    :crypto.strong_rand_bytes(20)
    |> VeChain.Utils.hex_encode(true)
  end
end
