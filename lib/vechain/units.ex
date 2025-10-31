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

  @wei_per_vet 1_000_000_000_000_000_000
  @wei_per_vtho 1_000_000_000_000_000_000

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
  @spec vet(number()) :: non_neg_integer()
  def vet(amount) when is_number(amount) do
    trunc(amount * @wei_per_vet)
  end

  @doc """
  Convert VTHO to wei.

  Accepts integers or floats and returns the wei amount as an integer.

  ## Examples

      iex> VeChain.Units.vtho(1)
      1_000_000_000_000_000_000

      iex> VeChain.Units.vtho(2.5)
      2_500_000_000_000_000_000

      iex> VeChain.Units.vtho(100)
      100_000_000_000_000_000_000
  """
  @spec vtho(number()) :: non_neg_integer()
  def vtho(amount) when is_number(amount) do
    trunc(amount * @wei_per_vtho)
  end

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
  @spec to_vet(non_neg_integer()) :: float()
  def to_vet(wei_amount) when is_integer(wei_amount) and wei_amount >= 0 do
    wei_amount / @wei_per_vet
  end

  @doc """
  Convert wei to VTHO.

  Returns a float representing the VTHO amount.

  ## Examples

      iex> VeChain.Units.to_vtho(1_000_000_000_000_000_000)
      1.0

      iex> VeChain.Units.to_vtho(2_500_000_000_000_000_000)
      2.5

      iex> VeChain.Units.to_vtho(100_000_000_000_000_000_000)
      100.0
  """
  @spec to_vtho(non_neg_integer()) :: float()
  def to_vtho(wei_amount) when is_integer(wei_amount) and wei_amount >= 0 do
    wei_amount / @wei_per_vtho
  end

  @doc """
  Identity function for wei amounts.

  Useful for explicit clarity when working with wei directly.

  ## Examples

      iex> VeChain.Units.wei(1000)
      1000

      iex> VeChain.Units.wei(1_000_000_000_000_000_000)
      1_000_000_000_000_000_000
  """
  @spec wei(non_neg_integer()) :: non_neg_integer()
  def wei(amount) when is_integer(amount) and amount >= 0 do
    amount
  end

  @doc """
  Format wei amount as VET string with specified decimal places.

  ## Examples

      iex> VeChain.Units.format_vet(1_000_000_000_000_000_000)
      "1.0 VET"

      iex> VeChain.Units.format_vet(1_500_000_000_000_000_000, decimals: 2)
      "1.50 VET"

      iex> VeChain.Units.format_vet(123_456_789_000_000_000, decimals: 4)
      "0.1235 VET"
  """
  @spec format_vet(non_neg_integer(), keyword()) :: String.t()
  def format_vet(wei_amount, opts \\ []) when is_integer(wei_amount) and wei_amount >= 0 do
    decimals = Keyword.get(opts, :decimals, 2)
    vet_amount = to_vet(wei_amount)
    "#{Float.round(vet_amount, decimals)} VET"
  end

  @doc """
  Format wei amount as VTHO string with specified decimal places.

  ## Examples

      iex> VeChain.Units.format_vtho(1_000_000_000_000_000_000)
      "1.0 VTHO"

      iex> VeChain.Units.format_vtho(2_500_000_000_000_000_000, decimals: 2)
      "2.50 VTHO"

      iex> VeChain.Units.format_vtho(987_654_321_000_000_000, decimals: 4)
      "0.9877 VTHO"
  """
  @spec format_vtho(non_neg_integer(), keyword()) :: String.t()
  def format_vtho(wei_amount, opts \\ []) when is_integer(wei_amount) and wei_amount >= 0 do
    decimals = Keyword.get(opts, :decimals, 2)
    vtho_amount = to_vtho(wei_amount)
    "#{Float.round(vtho_amount, decimals)} VTHO"
  end
end
