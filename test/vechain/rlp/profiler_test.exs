defmodule VeChain.RLP.ProfilerTest do
  use ExUnit.Case, async: true

  alias VeChain.RLP.{Profiler, Profile}
  alias VeChain.RLP.Kind.{Numeric, HexBlob, FixedHexBlob, CompactFixedHexBlob, OptionalFixedHexBlob}

  describe "of_object/2 with numeric profile" do
    test "encodes simple numeric value" do
      profile = %Profile{name: "value", kind: Numeric}
      {:ok, profiler} = Profiler.of_object(1000, profile)

      assert is_binary(profiler.encoded)
      assert profiler.decoded == <<0x03, 0xE8>>
    end

    test "encodes zero" do
      profile = %Profile{name: "value", kind: Numeric}
      {:ok, profiler} = Profiler.of_object(0, profile)

      assert profiler.decoded == <<>>
    end

    test "encodes with max_bytes constraint" do
      profile = %Profile{name: "value", kind: Numeric, opts: [max_bytes: 1]}
      {:ok, profiler} = Profiler.of_object(255, profile)

      assert profiler.decoded == <<0xFF>>
    end

    test "errors when exceeding max_bytes" do
      profile = %Profile{name: "value", kind: Numeric, opts: [max_bytes: 1]}
      {:error, msg} = Profiler.of_object(256, profile)

      assert msg =~ "exceeds max_bytes"
    end
  end

  describe "of_object/2 with hex blob profile" do
    test "encodes hex blob" do
      profile = %Profile{name: "data", kind: HexBlob}
      {:ok, profiler} = Profiler.of_object("0x1234abcd", profile)

      assert profiler.decoded == <<0x12, 0x34, 0xAB, 0xCD>>
    end

    test "errors without 0x prefix" do
      profile = %Profile{name: "data", kind: HexBlob}
      {:error, msg} = Profiler.of_object("1234", profile)

      assert msg =~ "must start with 0x"
    end

    test "errors with odd length" do
      profile = %Profile{name: "data", kind: HexBlob}
      {:error, msg} = Profiler.of_object("0x123", profile)

      assert msg =~ "must have even length"
    end
  end

  describe "of_object/2 with struct profile" do
    test "encodes simple struct" do
      profile = %Profile{
        name: "tx",
        kind: [
          %Profile{name: "nonce", kind: Numeric},
          %Profile{name: "value", kind: Numeric}
        ]
      }

      obj = %{"nonce" => 1, "value" => 1000}
      {:ok, profiler} = Profiler.of_object(obj, profile)

      assert profiler.decoded == [<<1>>, <<0x03, 0xE8>>]
    end

    test "supports atom keys" do
      profile = %Profile{
        name: "tx",
        kind: [
          %Profile{name: "nonce", kind: Numeric},
          %Profile{name: "value", kind: Numeric}
        ]
      }

      obj = %{nonce: 1, value: 1000}
      {:ok, profiler} = Profiler.of_object(obj, profile)

      assert profiler.decoded == [<<1>>, <<0x03, 0xE8>>]
    end

    test "encodes nested struct" do
      clause_profile = [
        %Profile{name: "to", kind: FixedHexBlob, opts: [bytes: 20]},
        %Profile{name: "value", kind: Numeric}
      ]

      profile = %Profile{
        name: "tx",
        kind: [
          %Profile{name: "nonce", kind: Numeric},
          %Profile{name: "clause", kind: clause_profile}
        ]
      }

      obj = %{
        "nonce" => 1,
        "clause" => %{
          "to" => "0x" <> String.duplicate("ab", 20),
          "value" => 1000
        }
      }

      {:ok, profiler} = Profiler.of_object(obj, profile)
      assert is_list(profiler.decoded)
      assert length(profiler.decoded) == 2
    end
  end

  describe "of_object/2 with array profile" do
    test "encodes array of numbers" do
      profile = %Profile{
        name: "numbers",
        kind: {:array, Numeric}
      }

      {:ok, profiler} = Profiler.of_object([1, 2, 3], profile)
      assert profiler.decoded == [<<1>>, <<2>>, <<3>>]
    end

    test "encodes empty array" do
      profile = %Profile{
        name: "numbers",
        kind: {:array, Numeric}
      }

      {:ok, profiler} = Profiler.of_object([], profile)
      assert profiler.decoded == []
    end

    test "encodes array of structs" do
      item_profile = [
        %Profile{name: "value", kind: Numeric}
      ]

      profile = %Profile{
        name: "items",
        kind: {:array, item_profile}
      }

      {:ok, profiler} = Profiler.of_object([%{"value" => 1}, %{"value" => 2}], profile)
      assert profiler.decoded == [[<<1>>], [<<2>>]]
    end
  end

  describe "of_object_encoded/2 and object/1" do
    test "decodes numeric value" do
      profile = %Profile{name: "value", kind: Numeric}
      {:ok, profiler} = Profiler.of_object(1000, profile)

      {:ok, decoded_profiler} = Profiler.of_object_encoded(profiler.encoded, profile)
      assert Profiler.object(decoded_profiler) == 1000
    end

    test "decodes struct" do
      profile = %Profile{
        name: "tx",
        kind: [
          %Profile{name: "nonce", kind: Numeric},
          %Profile{name: "value", kind: Numeric}
        ]
      }

      obj = %{"nonce" => 1, "value" => 1000}
      {:ok, profiler} = Profiler.of_object(obj, profile)

      {:ok, decoded_profiler} = Profiler.of_object_encoded(profiler.encoded, profile)
      decoded_obj = Profiler.object(decoded_profiler)

      assert decoded_obj["nonce"] == 1
      assert decoded_obj["value"] == 1000
    end

    test "decodes array" do
      profile = %Profile{
        name: "numbers",
        kind: {:array, Numeric}
      }

      {:ok, profiler} = Profiler.of_object([1, 2, 3], profile)

      {:ok, decoded_profiler} = Profiler.of_object_encoded(profiler.encoded, profile)
      assert Profiler.object(decoded_profiler) == [1, 2, 3]
    end
  end

  describe "roundtrip with complex profile" do
    test "VeChain-like transaction structure" do
      clause_profile = [
        %Profile{name: "to", kind: OptionalFixedHexBlob, opts: [bytes: 20]},
        %Profile{name: "value", kind: Numeric},
        %Profile{name: "data", kind: HexBlob}
      ]

      profile = %Profile{
        name: "transaction",
        kind: [
          %Profile{name: "chainTag", kind: Numeric, opts: [max_bytes: 1]},
          %Profile{name: "blockRef", kind: CompactFixedHexBlob, opts: [bytes: 8]},
          %Profile{name: "expiration", kind: Numeric, opts: [max_bytes: 4]},
          %Profile{name: "clauses", kind: {:array, clause_profile}},
          %Profile{name: "gasPriceCoef", kind: Numeric, opts: [max_bytes: 1]},
          %Profile{name: "gas", kind: Numeric, opts: [max_bytes: 8]},
          %Profile{name: "dependsOn", kind: OptionalFixedHexBlob, opts: [bytes: 32]},
          %Profile{name: "nonce", kind: Numeric, opts: [max_bytes: 8]}
        ]
      }

      tx = %{
        "chainTag" => 1,
        "blockRef" => "0x00000000aabbccdd",
        "expiration" => 1000,
        "clauses" => [
          %{
            "to" => "0x" <> String.duplicate("ab", 20),
            "value" => 1000,
            "data" => "0x"
          }
        ],
        "gasPriceCoef" => 0,
        "gas" => 21000,
        "dependsOn" => "",
        "nonce" => 12345678
      }

      {:ok, profiler} = Profiler.of_object(tx, profile)
      {:ok, decoded_profiler} = Profiler.of_object_encoded(profiler.encoded, profile)
      decoded_tx = Profiler.object(decoded_profiler)

      assert decoded_tx["chainTag"] == 1
      assert decoded_tx["blockRef"] == "0x00000000aabbccdd"
      assert decoded_tx["expiration"] == 1000
      assert length(decoded_tx["clauses"]) == 1
      assert decoded_tx["gasPriceCoef"] == 0
      assert decoded_tx["gas"] == 21000
      assert decoded_tx["dependsOn"] == ""
      assert decoded_tx["nonce"] == 12345678
    end
  end
end
