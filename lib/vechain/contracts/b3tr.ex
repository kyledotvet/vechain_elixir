defmodule VeChain.Contracts.B3TR do
  @moduledoc """
  B3TR token contract interface.

  ## Contract Address

  - Mainnet: `0x5ef79995FE8a89e0812330E4378eB2660ceDe699`
  """
  @b3tr_address "0x5ef79995FE8a89e0812330E4378eB2660ceDe699"

  use VeChain.Contract,
    abi_file: "priv/abi/vebetter_dao/b3tr.json",
    default_address: @b3tr_address
end
