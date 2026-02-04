defmodule VeChain.Contracts.Stargate do
  @moduledoc """
  Module for interacting with the Stargate contract on VeChain.
  """

  @stargate_address "0x03c557be98123fdb6fad325328ac6eb77de7248c"

  use VeChain.Contract,
    abi_file: "priv/abi/stargate.json",
    default_address: @stargate_address
end
