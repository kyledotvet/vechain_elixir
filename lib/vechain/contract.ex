defmodule VeChain.Contract do
  @moduledoc """
  Provides a base module for VeChain smart contract interactions.
  This module uses `Ethers.Contract` under the hood and can set up
  any necessary configuration for VeChain contracts if it is needed
  in the future.
  """

  defmacro __using__(opts) do
    quote do
      use Ethers.Contract, unquote(opts)
    end
  end
end
