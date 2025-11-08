defmodule VeChain.Units do
  @moduledoc """
  Unit conversion helpers for VeChain tokens.

  VeChain uses wei as the smallest unit (10^-18):
  - 1 VET = 1,000,000,000,000,000,000 wei (10^18 wei)
  - 1 VTHO = 1,000,000,000,000,000,000 wei (10^18 wei)

  ## Examples

      iex> VeChain.Units.vet(1)
      1_000_000_000_000_000_000

      iex> VeChain.Units.vet(10.5)
      10_500_000_000_000_000_000

      iex> VeChain.Units.to_vet(1_000_000_000_000_000_000)
      1.0

      iex> VeChain.Units.vtho(5)
      5_000_000_000_000_000_000

      iex> VeChain.Units.wei(1000)
      1000
  """

  @wei_per_ether Integer.pow(10, 18)

  @type wei :: non_neg_integer()
  @type ether :: float()

  @doc """
  Convert VET to wei.

  Accepts integers or floats and returns the wei amount as an integer.

  ## Examples

      iex> VeChain.Units.vet(1)
      1_000_000_000_000_000_000

      iex> VeChain.Units.vet(0.5)
      500_000_000_000_000_000

      iex> VeChain.Units.vet(10)
      10_000_000_000_000_000_000
  """
  @spec from_vet(number()) :: wei()
  def from_vet(amount) when is_number(amount) do
    trunc(amount * @wei_per_ether)
  end

  defdelegate from_vtho(amount), to: __MODULE__, as: :from_vet

  @doc """
  Convert wei to VET.

  Returns a float representing the VET amount.

  ## Examples

      iex> VeChain.Units.to_vet(1_000_000_000_000_000_000)
      1.0

      iex> VeChain.Units.to_vet(500_000_000_000_000_000)
      0.5

      iex> VeChain.Units.to_vet(10_000_000_000_000_000_000)
      10.0
  """
  @spec to_vet(wei()) :: ether()
  def to_vet(wei_amount) when is_integer(wei_amount) and wei_amount >= 0 do
    wei_amount / @wei_per_ether
  end

  defdelegate to_vtho(wei_amount), to: __MODULE__, as: :to_vet
end
