defmodule VeChain.Contracts.VOT3 do
  @moduledoc """
  VOT3 token contract interface.

  ## Contract Address

  - Mainnet: `0x76Ca782B59C74d088C7D2Cce2f211BC00836c602`
  """
  @vot3_address "0x76Ca782B59C74d088C7D2Cce2f211BC00836c602"

  use VeChain.Contract,
    abi_file: "priv/abi/vebetter_dao/vot3.json",
    default_address: @vot3_address
end
