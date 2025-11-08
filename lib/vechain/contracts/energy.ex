defmodule VeChain.Contracts.Energy do
  @moduledoc """
  Energy (VTHO) contract interface.

  Energy and VTHO are the same contract - Energy is just an alias.
  This module delegates all calls to `VeChain.Contracts.VTHO`.

  The contract address is the same on all networks:
  `0x0000000000000000000000000000456E65726779`

  ## Examples

      # All functions work identically to VTHO
      iex> VeChain.Contracts.Energy.balance_of(
      ...>   "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
      ...>   network: :testnet
      ...> )
      {:ok, 1000000000000000000000}
  """

  alias VeChain.Contracts.VTHO

  @doc "Get Energy contract address. Returns the same address as VTHO."
  @spec address() :: String.t()
  defdelegate address(), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.name/1`"
  defdelegate name(opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.symbol/1`"
  defdelegate symbol(opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.decimals/1`"
  defdelegate decimals(opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.total_supply/1`"
  defdelegate total_supply(opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.balance_of/2`"
  defdelegate balance_of(address, opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.allowance/3`"
  defdelegate allowance(owner, spender, opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.transfer/2`"
  defdelegate transfer(to, amount), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.approve/2`"
  defdelegate approve(spender, amount), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.transfer_from/3`"
  defdelegate transfer_from(from, to, amount), to: VTHO
end
