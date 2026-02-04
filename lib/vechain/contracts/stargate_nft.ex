defmodule VeChain.Contracts.StargateNFT do
  @moduledoc """
  Module for interacting with the Stargate NFT contract on VeChain.
  """

  @stargate_nft_address "0x1856c533ac2d94340aaa8544d35a5c1d4a21dee7"

  use VeChain.Contract,
    abi_file: "priv/abi/stargate_nft.json",
    default_address: @stargate_nft_address
end
