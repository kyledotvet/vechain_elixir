defmodule VeChain.Contracts.Stargate do
  @moduledoc """
  Module for interacting with the Stargate NFT contract on VeChain.
  """

  @stargate_address "0x1856c533ac2d94340aaa8544d35a5c1d4a21dee7"

  use VeChain.Contract,
    abi_file: "priv/abis/StargateNFT.json",
    default_address: @stargate_address

  defmodule Delegation do
    @moduledoc """
    Module for interacting with the Stargate Delegation contract on VeChain.
    """

    @stargate_delegation_address "0x4cb1c9ef05b529c093371264fab2c93cc6cddb0e"

    use VeChain.Contract,
      abi_file: "priv/abis/StargateDelegation.json",
      default_address: @stargate_delegation_address
  end
end
