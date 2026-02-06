defmodule VeChain.TransactionTest do
  use ExUnit.Case, async: true

  alias VeChain.Transaction
  alias VeChain.Utils
  import VeChain.ClauseFixture

  doctest VeChain.Transaction

  describe "append_clause/2" do
    test "appends a clause to the transaction" do
      initial_clause = clause_fixture()
      new_clause = clause_fixture()
      transaction = %VeChain.Transaction.Eip1559{clauses: [initial_clause]}

      assert Transaction.append_clause(transaction, new_clause) == %VeChain.Transaction.Eip1559{
               gas: 38904,
               clauses: [initial_clause, new_clause]
             }
    end

    test "appends multiple clauses correctly" do
      clause1 = clause_fixture()
      clause2 = clause_fixture()
      clause3 = clause_fixture()
      transaction = %VeChain.Transaction.Eip1559{clauses: [clause1]}

      transaction =
        transaction
        |> Transaction.append_clause(clause2)
        |> Transaction.append_clause(clause3)

      assert transaction.clauses == [clause1, clause2, clause3]
    end

    test "recalculates gas and hash after appending clause" do
    end
  end

  describe "cast/1" do
    test "decodes a raw transaction hex string or binary" do
      raw_tx =
        "0x51f901244a88016da36825315ad964f87af85c940000000000000000000000000000456e6572677980b844095ea7b300000000000000000000000040dc1e247569e4b66b25dda1ae3da6077632d68d0000000000000000000000000000000000000000000000056bc75e2d63100000db9440dc1e247569e4b66b25dda1ae3da6077632d68d80840c43f6d18527b960d782860a9d46cb0f828304a92980843be12077c101b882f0f101b6f8126cd442d54736c71532fda335498dcf59ed1c856d36174a324c9c6572b8355de320b59f0aa3cb122c15bd544374b95c4bd722a6c4232735e8790900190b390cecbadb572cd7862f21c9cb0e27f2b0831554e215ff0660282f6eba124314cd7008ecdd9fab7ab096ea49f9522cc8d751bebef2afc57c2a6c23e46a0601"

      decoded_tx = Transaction.cast(raw_tx)

      assert decoded_tx == %VeChain.Transaction.Eip1559{
               id: nil,
               chain_tag: <<0x4A>>,
               block_ref: <<1, 109, 163, 104, 37, 49, 90, 217>>,
               expiration: <<100>>,
               max_priority_fee_per_gas: <<39, 185, 96, 215, 130>>,
               max_fee_per_gas: <<10, 157, 70, 203, 15, 130>>,
               gas: <<4, 169, 41>>,
               depends_on: <<>>,
               nonce: <<59, 225, 32, 119>>,
               signature:
                 <<240, 241, 1, 182, 248, 18, 108, 212, 66, 213, 71, 54, 199, 21, 50, 253, 163,
                   53, 73, 141, 207, 89, 237, 28, 133, 109, 54, 23, 74, 50, 76, 156, 101, 114,
                   184, 53, 93, 227, 32, 181, 159, 10, 163, 203, 18, 44, 21, 189, 84, 67, 116,
                   185, 92, 75, 215, 34, 166, 196, 35, 39, 53, 232, 121, 9, 0, 25, 11, 57, 12,
                   236, 186, 219, 87, 44, 215, 134, 47, 33, 201, 203, 14, 39, 242, 176, 131, 21,
                   84, 226, 21, 255, 6, 96, 40, 47, 110, 186, 18, 67, 20, 205, 112, 8, 236, 221,
                   159, 171, 122, 176, 150, 234, 73, 249, 82, 44, 200, 215, 81, 190, 190, 242,
                   175, 197, 124, 42, 108, 35, 228, 106, 6, 1>>,
               origin:
                 <<5, 14, 247, 53, 211, 243, 108, 189, 160, 156, 238, 94, 102, 177, 123, 208, 214,
                   158, 124, 190>>,
               delegator:
                 <<252, 90, 139, 191, 240, 207, 198, 22, 71, 39, 114, 22, 112, 36, 231, 205, 151,
                   127, 39, 246>>,
               clauses: [
                 %VeChain.Transaction.Clause{
                   to: Utils.decode_address!("0x0000000000000000000000000000456E65726779"),
                   value: <<>>,
                   data:
                     Utils.hex_decode!(
                       "0x095ea7b300000000000000000000000040dc1e247569e4b66b25dda1ae3da6077632d68d0000000000000000000000000000000000000000000000056bc75e2d63100000"
                     )
                 },
                 %VeChain.Transaction.Clause{
                   to: Utils.decode_address!("0x40dc1E247569e4b66B25dDa1Ae3da6077632d68D"),
                   value: <<>>,
                   data: Utils.hex_decode!("0x0c43f6d1")
                 }
               ],
               reserved: %VeChain.Transaction.Reserved{features: <<1>>, unused: []}
             }
    end
  end
end
