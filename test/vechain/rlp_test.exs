defmodule VeChain.RLPTest do
  use ExUnit.Case, async: true
  doctest VeChain.RLP

  alias VeChain.RLP

  describe "encode/1" do
    test "encodes integers" do
      assert RLP.encode(0) == <<128>>
      assert RLP.encode(127) == <<127>>
      assert RLP.encode(128) == <<129, 128>>
      assert RLP.encode(1024) == <<130, 4, 0>>
    end

    test "encodes strings" do
      assert RLP.encode("") == <<128>>
      assert RLP.encode("dog") == <<131, 100, 111, 103>>
      assert RLP.encode("hello") == <<133, 104, 101, 108, 108, 111>>
    end

    test "encodes lists" do
      assert RLP.encode([]) == <<192>>
      assert RLP.encode([1, 2, 3]) == <<195, 1, 2, 3>>
      assert RLP.encode(["cat", "dog"]) == <<200, 131, 99, 97, 116, 131, 100, 111, 103>>
    end

    test "encodes nested lists" do
      assert RLP.encode([1, [2, 3]]) == <<196, 1, 194, 2, 3>>
      assert RLP.encode([[], [[]], [[], []]]) == <<198, 192, 193, 192, 194, 192, 192>>
    end
  end

  describe "decode/1" do
    test "decodes integers" do
      assert RLP.decode(<<128>>) == ""
      assert RLP.decode(<<127>>) == 127
      assert RLP.decode(<<129, 128>>) == <<128>>
    end

    test "decodes strings" do
      assert RLP.decode(<<131, 100, 111, 103>>) == "dog"
      assert RLP.decode(<<133, 104, 101, 108, 108, 111>>) == "hello"
    end

    test "decodes lists" do
      assert RLP.decode(<<192>>) == []
      assert RLP.decode(<<195, 1, 2, 3>>) == [1, 2, 3]
      assert RLP.decode(<<200, 131, 99, 97, 116, 131, 100, 111, 103>>) == ["cat", "dog"]
    end

    test "decodes nested lists" do
      assert RLP.decode(<<196, 1, 194, 2, 3>>) == [1, [2, 3]]
    end
  end

  describe "encode_transaction/1" do
    test "encodes basic transaction" do
      tx = %{
        chain_tag: 1,
        block_ref: <<0, 0, 0, 0, 0, 0, 0, 0>>,
        expiration: 32,
        clauses: [],
        gas_price_coef: 0,
        gas: 21000,
        depends_on: nil,
        nonce: 12_345_678,
        reserved: []
      }

      encoded = RLP.encode_transaction(tx)
      assert is_binary(encoded)
      assert byte_size(encoded) > 0
    end

    test "encodes transaction with clauses" do
      tx = %{
        chain_tag: 1,
        block_ref: <<0, 0, 0, 0, 0, 0, 0, 0>>,
        expiration: 32,
        clauses: [
          %{to: <<1::160>>, value: 1000, data: ""}
        ],
        gas_price_coef: 0,
        gas: 21000,
        depends_on: nil,
        nonce: 12_345_678,
        reserved: []
      }

      encoded = RLP.encode_transaction(tx)
      assert is_binary(encoded)
    end

    test "encodes transaction with signature" do
      tx = %{
        chain_tag: 1,
        block_ref: <<0, 0, 0, 0, 0, 0, 0, 0>>,
        expiration: 32,
        clauses: [],
        gas_price_coef: 0,
        gas: 21000,
        depends_on: nil,
        nonce: 12_345_678,
        reserved: [],
        signature: <<0::520>>
      }

      encoded = RLP.encode_transaction(tx)
      assert is_binary(encoded)
    end

    test "encodes transaction with depends_on" do
      depends_on = <<1::256>>

      tx = %{
        chain_tag: 1,
        block_ref: <<0, 0, 0, 0, 0, 0, 0, 0>>,
        expiration: 32,
        clauses: [],
        gas_price_coef: 0,
        gas: 21000,
        depends_on: depends_on,
        nonce: 12_345_678,
        reserved: []
      }

      encoded = RLP.encode_transaction(tx)
      assert is_binary(encoded)
    end
  end

  describe "encode_clauses/1" do
    test "encodes empty clause list" do
      assert RLP.encode_clauses([]) == []
    end

    test "encodes single clause" do
      clauses = [%{to: <<1::160>>, value: 1000, data: ""}]
      encoded = RLP.encode_clauses(clauses)

      assert encoded == [[<<1::160>>, 1000, ""]]
    end

    test "encodes multiple clauses" do
      clauses = [
        %{to: <<1::160>>, value: 1000, data: ""},
        %{to: <<2::160>>, value: 2000, data: <<1, 2, 3>>}
      ]

      encoded = RLP.encode_clauses(clauses)

      assert length(encoded) == 2
      assert [[<<1::160>>, 1000, ""], [<<2::160>>, 2000, <<1, 2, 3>>]] == encoded
    end

    test "encodes contract creation clause (empty to)" do
      clauses = [%{to: nil, value: 0, data: <<1, 2, 3>>}]
      encoded = RLP.encode_clauses(clauses)

      assert encoded == [["", 0, <<1, 2, 3>>]]
    end
  end

  describe "decode_transaction/1" do
    test "decodes basic transaction" do
      tx = %{
        chain_tag: 1,
        block_ref: <<0, 0, 0, 0, 0, 0, 0, 0>>,
        expiration: 32,
        clauses: [],
        gas_price_coef: 0,
        gas: 21000,
        depends_on: nil,
        nonce: 12_345_678,
        reserved: []
      }

      encoded = RLP.encode_transaction(tx)
      decoded = RLP.decode_transaction(encoded)

      assert decoded.chain_tag == tx.chain_tag
      assert decoded.block_ref == tx.block_ref
      assert decoded.expiration == tx.expiration
      assert decoded.clauses == []
      assert decoded.gas_price_coef == tx.gas_price_coef
      assert decoded.gas == tx.gas
      assert decoded.depends_on == nil
      assert decoded.nonce == tx.nonce
    end

    test "decodes transaction with signature" do
      signature = <<0::520>>

      tx = %{
        chain_tag: 1,
        block_ref: <<0, 0, 0, 0, 0, 0, 0, 0>>,
        expiration: 32,
        clauses: [],
        gas_price_coef: 0,
        gas: 21000,
        depends_on: nil,
        nonce: 12_345_678,
        reserved: [],
        signature: signature
      }

      encoded = RLP.encode_transaction(tx)
      decoded = RLP.decode_transaction(encoded)

      assert decoded.signature == signature
    end
  end

  describe "decode_clauses/1" do
    test "decodes empty clause list" do
      assert RLP.decode_clauses([]) == []
    end

    test "decodes single clause" do
      rlp_clauses = [[<<1::160>>, 1000, ""]]
      decoded = RLP.decode_clauses(rlp_clauses)

      assert [%{to: <<1::160>>, value: 1000, data: ""}] == decoded
    end

    test "decodes contract creation clause" do
      rlp_clauses = [["", 0, <<1, 2, 3>>]]
      decoded = RLP.decode_clauses(rlp_clauses)

      assert [%{to: nil, value: 0, data: <<1, 2, 3>>}] == decoded
    end
  end

  describe "roundtrip" do
    test "transaction roundtrip without signature" do
      tx = %{
        chain_tag: 39,
        block_ref: <<0, 1, 2, 3, 4, 5, 6, 7>>,
        expiration: 720,
        clauses: [
          %{to: <<1::160>>, value: 1000, data: ""},
          %{to: <<2::160>>, value: 2000, data: <<0xAB, 0xCD>>}
        ],
        gas_price_coef: 128,
        gas: 50000,
        depends_on: <<1::256>>,
        nonce: 98_765_432,
        reserved: []
      }

      encoded = RLP.encode_transaction(tx)
      decoded = RLP.decode_transaction(encoded)

      assert decoded.chain_tag == tx.chain_tag
      assert decoded.block_ref == tx.block_ref
      assert decoded.expiration == tx.expiration
      assert length(decoded.clauses) == 2
      assert decoded.gas_price_coef == tx.gas_price_coef
      assert decoded.gas == tx.gas
      assert decoded.depends_on == tx.depends_on
      assert decoded.nonce == tx.nonce
    end

    test "transaction roundtrip with signature" do
      tx = %{
        chain_tag: 39,
        block_ref: <<0, 1, 2, 3, 4, 5, 6, 7>>,
        expiration: 720,
        clauses: [],
        gas_price_coef: 0,
        gas: 21000,
        depends_on: nil,
        nonce: 12_345_678,
        reserved: [],
        signature: <<42::520>>
      }

      encoded = RLP.encode_transaction(tx)
      decoded = RLP.decode_transaction(encoded)

      assert decoded.signature == tx.signature
    end
  end
end
