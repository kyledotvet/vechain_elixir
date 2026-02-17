defmodule VeChain.ClauseFixture do
  @moduledoc """
  Test helpers for creating transaction clause entities.
  """
  def clause_fixture(attrs \\ %{}) do
    attrs
    |> Map.merge(%VeChain.Transaction.Clause{
      to: VeChain.AddressFixture.random_address(),
      value: <<>>,
      data: "0x000000606060"
    })
  end
end
