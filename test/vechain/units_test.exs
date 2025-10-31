defmodule VeChain.UnitsTest do
  use ExUnit.Case, async: true

  alias VeChain.Units

  doctest VeChain.Units

  @wei_per_vet 1_000_000_000_000_000_000
  @wei_per_vtho 1_000_000_000_000_000_000

  describe "vet/1" do
    test "converts VET to wei" do
      assert Units.vet(1) == @wei_per_vet
      assert Units.vet(10) == 10 * @wei_per_vet
      assert Units.vet(0.5) == div(@wei_per_vet, 2)
    end

    test "handles zero" do
      assert Units.vet(0) == 0
    end

    test "handles fractional amounts" do
      assert Units.vet(0.1) == div(@wei_per_vet, 10)
      assert Units.vet(0.01) == div(@wei_per_vet, 100)
    end

    test "handles large amounts" do
      assert Units.vet(1_000_000) == 1_000_000 * @wei_per_vet
    end
  end

  describe "vtho/1" do
    test "converts VTHO to wei" do
      assert Units.vtho(1) == @wei_per_vtho
      assert Units.vtho(100) == 100 * @wei_per_vtho
      assert Units.vtho(0.25) == div(@wei_per_vtho, 4)
    end

    test "handles zero" do
      assert Units.vtho(0) == 0
    end

    test "handles fractional amounts" do
      assert Units.vtho(0.1) == div(@wei_per_vtho, 10)
      assert Units.vtho(0.001) == div(@wei_per_vtho, 1000)
    end
  end

  describe "wei/1" do
    test "converts integer to wei" do
      assert Units.wei(1000) == 1000
      assert Units.wei(0) == 0
    end

    test "is identity function for integers" do
      amount = 123_456_789
      assert Units.wei(amount) == amount
    end
  end

  describe "to_vet/1" do
    test "converts wei to VET" do
      assert Units.to_vet(@wei_per_vet) == 1.0
      assert Units.to_vet(10 * @wei_per_vet) == 10.0
    end

    test "handles fractional VET" do
      assert Units.to_vet(div(@wei_per_vet, 2)) == 0.5
      assert Units.to_vet(div(@wei_per_vet, 10)) == 0.1
    end

    test "handles zero" do
      assert Units.to_vet(0) == 0.0
    end

    test "handles small amounts" do
      assert Units.to_vet(1) == 1.0e-18
    end
  end

  describe "to_vtho/1" do
    test "converts wei to VTHO" do
      assert Units.to_vtho(@wei_per_vtho) == 1.0
      assert Units.to_vtho(100 * @wei_per_vtho) == 100.0
    end

    test "handles fractional VTHO" do
      assert Units.to_vtho(div(@wei_per_vtho, 4)) == 0.25
    end

    test "handles zero" do
      assert Units.to_vtho(0) == 0.0
    end
  end

  describe "format_vet/1" do
    test "formats VET with units" do
      assert Units.format_vet(@wei_per_vet) == "1.0 VET"
      assert Units.format_vet(10 * @wei_per_vet) == "10.0 VET"
    end

    test "formats fractional amounts" do
      assert Units.format_vet(div(@wei_per_vet, 2)) == "0.5 VET"
    end

    test "handles custom precision" do
      assert Units.format_vet(@wei_per_vet, precision: 2) == "1.00 VET"
      assert Units.format_vet(@wei_per_vet, precision: 4) == "1.0000 VET"
    end
  end

  describe "format_vtho/1" do
    test "formats VTHO with units" do
      assert Units.format_vtho(@wei_per_vtho) == "1.0 VTHO"
      assert Units.format_vtho(100 * @wei_per_vtho) == "100.0 VTHO"
    end

    test "handles custom precision" do
      assert Units.format_vtho(@wei_per_vtho, precision: 3) == "1.000 VTHO"
    end
  end

  describe "parse_vet/1" do
    test "parses VET string" do
      assert Units.parse_vet("1.0 VET") == {:ok, @wei_per_vet}
      assert Units.parse_vet("10 VET") == {:ok, 10 * @wei_per_vet}
    end

    test "parses VET without unit" do
      assert Units.parse_vet("1.0") == {:ok, @wei_per_vet}
      assert Units.parse_vet("5") == {:ok, 5 * @wei_per_vet}
    end

    test "handles fractional amounts" do
      assert Units.parse_vet("0.5 VET") == {:ok, div(@wei_per_vet, 2)}
    end

    test "returns error for invalid format" do
      assert {:error, _} = Units.parse_vet("invalid")
      assert {:error, _} = Units.parse_vet("abc VET")
    end
  end

  describe "parse_vtho/1" do
    test "parses VTHO string" do
      assert Units.parse_vtho("1.0 VTHO") == {:ok, @wei_per_vtho}
      assert Units.parse_vtho("100 VTHO") == {:ok, 100 * @wei_per_vtho}
    end

    test "parses VTHO without unit" do
      assert Units.parse_vtho("1.0") == {:ok, @wei_per_vtho}
    end

    test "returns error for invalid format" do
      assert {:error, _} = Units.parse_vtho("invalid")
    end
  end

  describe "conversions are reversible" do
    test "vet to wei and back" do
      original = 10.5
      wei = Units.vet(original)
      converted = Units.to_vet(wei)

      assert_in_delta original, converted, 1.0e-10
    end

    test "vtho to wei and back" do
      original = 100.25
      wei = Units.vtho(original)
      converted = Units.to_vtho(wei)

      assert_in_delta original, converted, 1.0e-10
    end
  end
end
