defmodule VeChain.Transaction.ProfileTest do
  use ExUnit.Case, async: true

  alias VeChain.Transaction.Profile

  describe "clause_profile/0" do
    test "returns valid clause profile" do
      profile = Profile.clause_profile()
      assert is_list(profile)
      assert length(profile) == 3
    end
  end

  describe "transaction_profile/0" do
    test "returns valid transaction profile" do
      profile = Profile.transaction_profile()
      assert profile.name == "transaction"
      assert is_list(profile.kind)
      assert length(profile.kind) == 9
    end
  end

  describe "signed_transaction_profile/0" do
    test "returns valid signed transaction profile" do
      profile = Profile.signed_transaction_profile()
      assert profile.name == "signed_transaction"
      assert is_list(profile.kind)
      assert length(profile.kind) == 10
    end
  end

  describe "encode/1 and decode/1" do
    test "encodes and decodes simple unsigned transaction" do
      tx = %{
        "chainTag" => 1,
        "blockRef" => "0x00000000aabbccdd",
        "expiration" => 1000,
        "clauses" => [],
        "gasPriceCoef" => 0,
        "gas" => 21000,
        "dependsOn" => "",
        "nonce" => 12345678,
        "reserved" => []
      }

      {:ok, encoded} = Profile.encode(tx)
      assert is_binary(encoded)

      {:ok, decoded} = Profile.decode(encoded)
      assert decoded["chainTag"] == 1
      assert decoded["blockRef"] == "0x00000000aabbccdd"
      assert decoded["expiration"] == 1000
      assert decoded["clauses"] == []
      assert decoded["gasPriceCoef"] == 0
      assert decoded["gas"] == 21000
      assert decoded["dependsOn"] == ""
      assert decoded["nonce"] == 12345678
      assert decoded["reserved"] == []
    end

    test "encodes and decodes transaction with clauses" do
      tx = %{
        "chainTag" => 39,
        "blockRef" => "0x00000000aabbccdd",
        "expiration" => 720,
        "clauses" => [
          %{
            "to" => "0x" <> String.duplicate("ab", 20),
            "value" => 1000,
            "data" => "0x"
          },
          %{
            "to" => "0x" <> String.duplicate("cd", 20),
            "value" => 2000,
            "data" => "0x1234"
          }
        ],
        "gasPriceCoef" => 128,
        "gas" => 50000,
        "dependsOn" => "",
        "nonce" => 98765432,
        "reserved" => []
      }

      {:ok, encoded} = Profile.encode(tx)
      {:ok, decoded} = Profile.decode(encoded)

      assert decoded["chainTag"] == 39
      assert decoded["expiration"] == 720
      assert length(decoded["clauses"]) == 2
      assert decoded["gasPriceCoef"] == 128
      assert decoded["gas"] == 50000
      assert decoded["nonce"] == 98765432
    end

    test "encodes and decodes transaction with contract creation clause" do
      tx = %{
        "chainTag" => 1,
        "blockRef" => "0x0000000000000000",
        "expiration" => 1000,
        "clauses" => [
          %{
            "to" => "",
            "value" => 0,
            "data" => "0x608060405234801561001057600080fd5b50"
          }
        ],
        "gasPriceCoef" => 0,
        "gas" => 1000000,
        "dependsOn" => "",
        "nonce" => 1,
        "reserved" => []
      }

      {:ok, encoded} = Profile.encode(tx)
      {:ok, decoded} = Profile.decode(encoded)

      assert decoded["clauses"] |> List.first() |> Map.get("to") == ""
      assert decoded["clauses"] |> List.first() |> Map.get("value") == 0
    end

    test "encodes and decodes transaction with dependsOn" do
      depends_on = "0x" <> String.duplicate("ab", 32)

      tx = %{
        "chainTag" => 1,
        "blockRef" => "0x00000000aabbccdd",
        "expiration" => 1000,
        "clauses" => [],
        "gasPriceCoef" => 0,
        "gas" => 21000,
        "dependsOn" => depends_on,
        "nonce" => 12345678,
        "reserved" => []
      }

      {:ok, encoded} = Profile.encode(tx)
      {:ok, decoded} = Profile.decode(encoded)

      assert decoded["dependsOn"] == depends_on
    end

    test "encodes and decodes signed transaction" do
      signature = "0x" <> String.duplicate("ab", 65)

      tx = %{
        "chainTag" => 1,
        "blockRef" => "0x00000000aabbccdd",
        "expiration" => 1000,
        "clauses" => [],
        "gasPriceCoef" => 0,
        "gas" => 21000,
        "dependsOn" => "",
        "nonce" => 12345678,
        "reserved" => [],
        "signature" => signature
      }

      {:ok, encoded} = Profile.encode(tx)
      {:ok, decoded} = Profile.decode(encoded)

      assert decoded["signature"] == signature
    end

    test "supports atom keys" do
      tx = %{
        chainTag: 1,
        blockRef: "0x00000000aabbccdd",
        expiration: 1000,
        clauses: [],
        gasPriceCoef: 0,
        gas: 21000,
        dependsOn: "",
        nonce: 12345678,
        reserved: []
      }

      {:ok, encoded} = Profile.encode(tx)
      {:ok, decoded} = Profile.decode(encoded)

      assert decoded["chainTag"] == 1
    end

    test "compact blockRef removes leading zeros" do
      tx = %{
        "chainTag" => 1,
        "blockRef" => "0x00000000aabbccdd",
        "expiration" => 1000,
        "clauses" => [],
        "gasPriceCoef" => 0,
        "gas" => 21000,
        "dependsOn" => "",
        "nonce" => 1,
        "reserved" => []
      }

      {:ok, encoded} = Profile.encode(tx)
      {:ok, decoded} = Profile.decode(encoded)

      # BlockRef should be restored to full 8 bytes after decoding
      assert decoded["blockRef"] == "0x00000000aabbccdd"
    end

    test "handles zero values correctly" do
      tx = %{
        "chainTag" => 0,
        "blockRef" => "0x0000000000000000",
        "expiration" => 0,
        "clauses" => [],
        "gasPriceCoef" => 0,
        "gas" => 0,
        "dependsOn" => "",
        "nonce" => 0,
        "reserved" => []
      }

      {:ok, encoded} = Profile.encode(tx)
      {:ok, decoded} = Profile.decode(encoded)

      assert decoded["chainTag"] == 0
      assert decoded["expiration"] == 0
      assert decoded["gas"] == 0
      assert decoded["nonce"] == 0
    end
  end

  describe "real VeChain transaction data" do
    test "decodes real transaction from example in analysis doc" do
      # This is a real VeChain transaction from the RLP_IMPLEMENTATION_ANALYSIS.md
      # Note: We'll construct a simplified version for testing
      tx = %{
        "chainTag" => 74,
        "blockRef" => "0x00000000aabbccdd",
        "expiration" => 1000,
        "clauses" => [
          %{
            "to" => "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            "value" => 1000,
            "data" => "0x"
          }
        ],
        "gasPriceCoef" => 0,
        "gas" => 21000,
        "dependsOn" => "",
        "nonce" => 12345678,
        "reserved" => []
      }

      {:ok, encoded} = Profile.encode(tx)
      {:ok, decoded} = Profile.decode(encoded)

      assert decoded["chainTag"] == 74
      assert decoded["clauses"] |> List.first() |> Map.get("to") ==
               "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"
    end
  end

  describe "error handling" do
    test "errors on invalid chain tag" do
      tx = %{
        "chainTag" => 256,  # Exceeds 1 byte
        "blockRef" => "0x00000000aabbccdd",
        "expiration" => 1000,
        "clauses" => [],
        "gasPriceCoef" => 0,
        "gas" => 21000,
        "dependsOn" => "",
        "nonce" => 1,
        "reserved" => []
      }

      {:error, msg} = Profile.encode(tx)
      assert msg =~ "max_bytes"
    end

    test "errors on invalid block ref format" do
      tx = %{
        "chainTag" => 1,
        "blockRef" => "invalid",  # Not a hex string
        "expiration" => 1000,
        "clauses" => [],
        "gasPriceCoef" => 0,
        "gas" => 21000,
        "dependsOn" => "",
        "nonce" => 1,
        "reserved" => []
      }

      {:error, msg} = Profile.encode(tx)
      assert msg =~ "must start with 0x"
    end

    test "errors on invalid clause address" do
      tx = %{
        "chainTag" => 1,
        "blockRef" => "0x00000000aabbccdd",
        "expiration" => 1000,
        "clauses" => [
          %{
            "to" => "0x1234",  # Wrong length
            "value" => 1000,
            "data" => "0x"
          }
        ],
        "gasPriceCoef" => 0,
        "gas" => 21000,
        "dependsOn" => "",
        "nonce" => 1,
        "reserved" => []
      }

      {:error, msg} = Profile.encode(tx)
      assert msg =~ "Expected 20 bytes"
    end
  end
end
