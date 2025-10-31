defmodule VeChain.ReservedTest do
  use ExUnit.Case, async: true

  alias VeChain.Reserved

  doctest VeChain.Reserved

  describe "new/0" do
    test "creates default reserved field" do
      reserved = Reserved.new()

      assert reserved.features == 0
      assert reserved.unused == []
    end
  end

  describe "new/1" do
    test "creates reserved with specified features" do
      reserved = Reserved.new(features: 1)

      assert reserved.features == 1
      assert reserved.unused == []
    end

    test "creates reserved with unused data" do
      reserved = Reserved.new(unused: [<<0x01>>, <<0x02>>])

      assert reserved.features == 0
      assert reserved.unused == [<<0x01>>, <<0x02>>]
    end
  end

  describe "enable_vip191/1" do
    test "sets VIP-191 bit on default reserved" do
      reserved = Reserved.new()
      reserved = Reserved.enable_vip191(reserved)

      assert Bitwise.band(reserved.features, 1) == 1
    end

    test "sets VIP-191 bit without affecting other bits" do
      reserved = Reserved.new(features: 0b10)
      reserved = Reserved.enable_vip191(reserved)

      assert reserved.features == 0b11
    end

    test "is idempotent" do
      reserved = Reserved.new()
      reserved = Reserved.enable_vip191(reserved)
      reserved = Reserved.enable_vip191(reserved)

      assert Bitwise.band(reserved.features, 1) == 1
    end
  end

  describe "disable_vip191/1" do
    test "clears VIP-191 bit" do
      reserved = Reserved.new(features: 1)
      reserved = Reserved.disable_vip191(reserved)

      assert Bitwise.band(reserved.features, 1) == 0
    end

    test "clears VIP-191 bit without affecting other bits" do
      reserved = Reserved.new(features: 0b11)
      reserved = Reserved.disable_vip191(reserved)

      assert reserved.features == 0b10
    end
  end

  describe "vip191_enabled?/1" do
    test "returns true when VIP-191 is enabled" do
      reserved = Reserved.new(features: 1)

      assert Reserved.vip191_enabled?(reserved)
    end

    test "returns false when VIP-191 is disabled" do
      reserved = Reserved.new(features: 0)

      refute Reserved.vip191_enabled?(reserved)
    end

    test "checks only VIP-191 bit" do
      reserved = Reserved.new(features: 0b10)

      refute Reserved.vip191_enabled?(reserved)
    end

    test "works with other bits set" do
      reserved = Reserved.new(features: 0b11)

      assert Reserved.vip191_enabled?(reserved)
    end
  end

  describe "encode/1" do
    test "encodes to RLP list with features and unused" do
      reserved = Reserved.new(features: 1, unused: [])

      encoded = Reserved.encode(reserved)

      assert is_list(encoded)
      assert length(encoded) == 2
      assert hd(encoded) == 1
      assert Enum.at(encoded, 1) == []
    end

    test "encodes with unused data" do
      reserved = Reserved.new(features: 0, unused: [<<0x01>>, <<0x02>>])

      encoded = Reserved.encode(reserved)

      assert Enum.at(encoded, 1) == [<<0x01>>, <<0x02>>]
    end

    test "encodes features as integer" do
      reserved = Reserved.new(features: 255)

      encoded = Reserved.encode(reserved)

      assert hd(encoded) == 255
    end
  end

  describe "decode/1" do
    test "decodes RLP list to reserved" do
      rlp_list = [1, []]

      {:ok, reserved} = Reserved.decode(rlp_list)

      assert reserved.features == 1
      assert reserved.unused == []
    end

    test "decodes with unused data" do
      rlp_list = [0, [<<0x01>>, <<0x02>>]]

      {:ok, reserved} = Reserved.decode(rlp_list)

      assert reserved.features == 0
      assert reserved.unused == [<<0x01>>, <<0x02>>]
    end

    test "handles empty unused list" do
      rlp_list = [1, []]

      {:ok, reserved} = Reserved.decode(rlp_list)

      assert reserved.unused == []
    end

    test "returns error for invalid format" do
      assert {:error, _} = Reserved.decode([])
      assert {:error, _} = Reserved.decode([1])
      assert {:error, _} = Reserved.decode("invalid")
    end
  end

  describe "feature bit manipulation" do
    test "can set and check multiple feature bits" do
      reserved = Reserved.new()
      reserved = %{reserved | features: Bitwise.bor(reserved.features, 1)}
      reserved = %{reserved | features: Bitwise.bor(reserved.features, 4)}

      assert Bitwise.band(reserved.features, 1) == 1
      assert Bitwise.band(reserved.features, 4) == 4
      assert reserved.features == 5
    end

    test "can clear specific bits" do
      reserved = Reserved.new(features: 0b1111)
      reserved = %{reserved | features: Bitwise.band(reserved.features, Bitwise.bnot(1))}

      assert Bitwise.band(reserved.features, 1) == 0
      assert reserved.features == 0b1110
    end
  end
end
