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

  @doc """
  Get Energy contract address.

  Returns the same address as VTHO.
  """
  @spec address() :: String.t()
  defdelegate address(), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.name/1`"
  @spec name(keyword()) :: {:ok, String.t()} | {:error, term()}
  defdelegate name(opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.symbol/1`"
  @spec symbol(keyword()) :: {:ok, String.t()} | {:error, term()}
  defdelegate symbol(opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.decimals/1`"
  @spec decimals(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  defdelegate decimals(opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.total_supply/1`"
  @spec total_supply(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  defdelegate total_supply(opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.balance_of/2`"
  @spec balance_of(String.t(), keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  defdelegate balance_of(address, opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.balance_of!/2`"
  @spec balance_of!(String.t(), keyword()) :: non_neg_integer()
  defdelegate balance_of!(address, opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.allowance/3`"
  @spec allowance(String.t(), String.t(), keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  defdelegate allowance(owner, spender, opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.allowance!/3`"
  @spec allowance!(String.t(), String.t(), keyword()) :: non_neg_integer()
  defdelegate allowance!(owner, spender, opts \\ []), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.transfer/2`"
  @spec transfer(String.t(), non_neg_integer()) :: VeChain.Clause.t()
  defdelegate transfer(to, amount), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.approve/2`"
  @spec approve(String.t(), non_neg_integer()) :: VeChain.Clause.t()
  defdelegate approve(spender, amount), to: VTHO

  @doc "See `VeChain.Contracts.VTHO.transfer_from/3`"
  @spec transfer_from(String.t(), String.t(), non_neg_integer()) :: VeChain.Clause.t()
  defdelegate transfer_from(from, to, amount), to: VTHO
end
