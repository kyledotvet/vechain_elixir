defmodule VeChain.Contract do
  @moduledoc """
  Provides a base module for VeChain smart contract interactions.
  This module uses `Ethers.Contract` under the hood and sets up
  any necessary configurations for VeChain contracts.
  """

  defmacro __using__(opts) do
    quote do
      use Ethers.Contract, unquote(opts)
    end
  end
end
