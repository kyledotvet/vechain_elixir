defmodule VeChain.Contracts.VNS do
  @moduledoc """
  VeChain Name Service (VNS) Registry contract interface.

  The VNS Registry is the core contract that manages domain ownership and resolution.
  It maintains records of domain ownership, resolvers, and TTL values.

  ## Contract Addresses

  - Mainnet: `0xa9231da8BF8D10e2df3f6E03Dd5449caD600129b`
  - Testnet: `0xcBFB30c1F267914816668d53AcBA7bA7c9806D13`
  """
  @vns_address "0xa9231da8BF8D10e2df3f6E03Dd5449caD600129b"

  use VeChain.Contract,
    abi_file: "priv/abi/vns_registry.json",
    default_address: @vns_address

  defmodule Resolver do
    @moduledoc """
    VNS Public Resolver contract interface.

    The Resolver contract handles the actual resolution of VNS domains to addresses,
    content hashes, and other metadata. It's the contract that stores the actual
    data associated with domain names.

    ## Contract Addresses

    - Mainnet: `0xabac49445584C8b6c1472b030B1076Ac3901D7cf`
    - Testnet: `0xA6eFd130085a127D090ACb0b100294aD1079EA6f`
    """
    @vns_resolver_address "0xabac49445584C8b6c1472b030B1076Ac3901D7cf"

    use VeChain.Contract,
      abi_file: "priv/abi/vns_public_resolver.json",
      default_address: @vns_resolver_address
  end
end
