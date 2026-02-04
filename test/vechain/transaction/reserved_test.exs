defmodule VeChain.Transaction.ReservedTest do
  use ExUnit.Case, async: true

  alias VeChain.Transaction.Reserved

  describe "ExRLP.Encode implementation" do
    test "encodes Reserved struct with features 0 as empty list" do
      reserved = %Reserved{features: 0}
      encoded = ExRLP.encode(reserved)
      assert encoded == ExRLP.encode([])
    end

    test "encodes Reserved struct with non-zero features correctly" do
      reserved = %Reserved{features: 5, unused: [<<1>>, <<2>>]}
      encoded = ExRLP.encode(reserved)

      assert encoded == [<<1>>, <<1>>, <<2>>] |> ExRLP.encode()
    end
  end
end
