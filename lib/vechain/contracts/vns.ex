defmodule VeChain.Contracts.VNS do
  @moduledoc """
  VeChain Name Service (VNS) Registry contract interface.

  The VNS Registry is the core contract that manages domain ownership and resolution.
  It maintains records of domain ownership, resolvers, and TTL values.

  ## Contract Addresses

  - Mainnet: `0xa9231da8BF8D10e2df3f6E03Dd5449caD600129b`
  - Testnet: (same address)

  ## Examples

      # Get the owner of a domain
      iex> node = VeChain.VNS.namehash("example.vet")
      iex> VeChain.Contracts.VNS.owner(node, network: :mainnet)
      {:ok, "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"}

      # Get the resolver for a domain
      iex> VeChain.Contracts.VNS.resolver(node, network: :mainnet)
      {:ok, "0xabac49445584C8b6c1472b030B1076Ac3901D7cf"}
  """
  @vns_address "0xa9231da8BF8D10e2df3f6E03Dd5449caD600129b"

  # VNS Registry ABI
  # Source: https://github.com/vechain/b32/blob/master/ABIs/vet-domains-registry.json
  @vns_registry_abi [
    # Events
    %{
      anonymous: false,
      inputs: [
        %{indexed: true, internalType: "address", name: "owner", type: "address"},
        %{indexed: true, internalType: "address", name: "operator", type: "address"},
        %{indexed: false, internalType: "bool", name: "approved", type: "bool"}
      ],
      name: "ApprovalForAll",
      type: "event"
    },
    %{
      anonymous: false,
      inputs: [
        %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
        %{indexed: true, internalType: "bytes32", name: "label", type: "bytes32"},
        %{indexed: false, internalType: "address", name: "owner", type: "address"}
      ],
      name: "NewOwner",
      type: "event"
    },
    %{
      anonymous: false,
      inputs: [
        %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
        %{indexed: false, internalType: "address", name: "resolver", type: "address"}
      ],
      name: "NewResolver",
      type: "event"
    },
    %{
      anonymous: false,
      inputs: [
        %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
        %{indexed: false, internalType: "uint64", name: "ttl", type: "uint64"}
      ],
      name: "NewTTL",
      type: "event"
    },
    %{
      anonymous: false,
      inputs: [
        %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
        %{indexed: false, internalType: "address", name: "owner", type: "address"}
      ],
      name: "Transfer",
      type: "event"
    },
    # Functions
    %{
      inputs: [
        %{internalType: "address", name: "owner", type: "address"},
        %{internalType: "address", name: "operator", type: "address"}
      ],
      name: "isApprovedForAll",
      outputs: [%{internalType: "bool", name: "", type: "bool"}],
      stateMutability: "view",
      type: "function"
    },
    %{
      inputs: [%{internalType: "bytes32", name: "node", type: "bytes32"}],
      name: "owner",
      outputs: [%{internalType: "address", name: "", type: "address"}],
      stateMutability: "view",
      type: "function"
    },
    %{
      inputs: [%{internalType: "bytes32", name: "node", type: "bytes32"}],
      name: "recordExists",
      outputs: [%{internalType: "bool", name: "", type: "bool"}],
      stateMutability: "view",
      type: "function"
    },
    %{
      inputs: [%{internalType: "bytes32", name: "node", type: "bytes32"}],
      name: "resolver",
      outputs: [%{internalType: "address", name: "", type: "address"}],
      stateMutability: "view",
      type: "function"
    },
    %{
      inputs: [
        %{internalType: "address", name: "operator", type: "address"},
        %{internalType: "bool", name: "approved", type: "bool"}
      ],
      name: "setApprovalForAll",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function"
    },
    %{
      inputs: [
        %{internalType: "bytes32", name: "node", type: "bytes32"},
        %{internalType: "address", name: "owner", type: "address"}
      ],
      name: "setOwner",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function"
    },
    %{
      inputs: [
        %{internalType: "bytes32", name: "node", type: "bytes32"},
        %{internalType: "address", name: "owner", type: "address"},
        %{internalType: "address", name: "resolver", type: "address"},
        %{internalType: "uint64", name: "ttl", type: "uint64"}
      ],
      name: "setRecord",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function"
    },
    %{
      inputs: [
        %{internalType: "bytes32", name: "node", type: "bytes32"},
        %{internalType: "address", name: "resolver", type: "address"}
      ],
      name: "setResolver",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function"
    },
    %{
      inputs: [
        %{internalType: "bytes32", name: "node", type: "bytes32"},
        %{internalType: "bytes32", name: "label", type: "bytes32"},
        %{internalType: "address", name: "owner", type: "address"}
      ],
      name: "setSubnodeOwner",
      outputs: [%{internalType: "bytes32", name: "", type: "bytes32"}],
      stateMutability: "nonpayable",
      type: "function"
    },
    %{
      inputs: [
        %{internalType: "bytes32", name: "node", type: "bytes32"},
        %{internalType: "bytes32", name: "label", type: "bytes32"},
        %{internalType: "address", name: "owner", type: "address"},
        %{internalType: "address", name: "resolver", type: "address"},
        %{internalType: "uint64", name: "ttl", type: "uint64"}
      ],
      name: "setSubnodeRecord",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function"
    },
    %{
      inputs: [
        %{internalType: "bytes32", name: "node", type: "bytes32"},
        %{internalType: "uint64", name: "ttl", type: "uint64"}
      ],
      name: "setTTL",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function"
    },
    %{
      inputs: [%{internalType: "bytes32", name: "node", type: "bytes32"}],
      name: "ttl",
      outputs: [%{internalType: "uint64", name: "", type: "uint64"}],
      stateMutability: "view",
      type: "function"
    }
  ]

  use VeChain.Contract,
    abi: @vns_registry_abi,
    default_address: @vns_address

  defmodule Resolver do
    @moduledoc """
    VNS Public Resolver contract interface.

    The Resolver contract handles the actual resolution of VNS domains to addresses,
    content hashes, and other metadata. It's the contract that stores the actual
    data associated with domain names.

    ## Contract Addresses

    - Mainnet: `0xabac49445584C8b6c1472b030B1076Ac3901D7cf`
    - Testnet: (same address)

    ## Examples

        # Resolve a domain to an address
        iex> node = VeChain.VNS.namehash("example.vet")
        iex> VeChain.Contracts.VNS.Resolver.addr(node, network: :mainnet)
        {:ok, "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"}

        # Get text record for a domain
        iex> VeChain.Contracts.VNS.Resolver.text(node, "email", network: :mainnet)
        {:ok, "contact@example.com"}
    """
    @vns_resolver_address "0xabac49445584C8b6c1472b030B1076Ac3901D7cf"

    # VNS Public Resolver ABI
    # Source: https://github.com/vechain/b32/blob/master/ABIs/vet-domains-publicResolver.json
    @vns_resolver_abi [
      # Events
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: true, internalType: "uint256", name: "contentType", type: "uint256"}
        ],
        name: "ABIChanged",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: false, internalType: "address", name: "a", type: "address"}
        ],
        name: "AddrChanged",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: false, internalType: "uint256", name: "coinType", type: "uint256"},
          %{indexed: false, internalType: "bytes", name: "newAddress", type: "bytes"}
        ],
        name: "AddressChanged",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "address", name: "owner", type: "address"},
          %{indexed: true, internalType: "address", name: "operator", type: "address"},
          %{indexed: false, internalType: "bool", name: "approved", type: "bool"}
        ],
        name: "ApprovalForAll",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: false, internalType: "address", name: "owner", type: "address"},
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: true, internalType: "address", name: "delegate", type: "address"},
          %{indexed: true, internalType: "bool", name: "approved", type: "bool"}
        ],
        name: "Approved",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: false, internalType: "bytes", name: "hash", type: "bytes"}
        ],
        name: "ContenthashChanged",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: false, internalType: "bytes", name: "name", type: "bytes"},
          %{indexed: false, internalType: "uint16", name: "resource", type: "uint16"},
          %{indexed: false, internalType: "bytes", name: "record", type: "bytes"}
        ],
        name: "DNSRecordChanged",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: false, internalType: "bytes", name: "name", type: "bytes"},
          %{indexed: false, internalType: "uint16", name: "resource", type: "uint16"}
        ],
        name: "DNSRecordDeleted",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: false, internalType: "bytes", name: "lastzonehash", type: "bytes"},
          %{indexed: false, internalType: "bytes", name: "zonehash", type: "bytes"}
        ],
        name: "DNSZonehashChanged",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: true, internalType: "bytes4", name: "interfaceID", type: "bytes4"},
          %{indexed: false, internalType: "address", name: "implementer", type: "address"}
        ],
        name: "InterfaceChanged",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: false, internalType: "string", name: "name", type: "string"}
        ],
        name: "NameChanged",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: false, internalType: "bytes32", name: "x", type: "bytes32"},
          %{indexed: false, internalType: "bytes32", name: "y", type: "bytes32"}
        ],
        name: "PubkeyChanged",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: true, internalType: "string", name: "indexedKey", type: "string"},
          %{indexed: false, internalType: "string", name: "key", type: "string"},
          %{indexed: false, internalType: "string", name: "value", type: "string"}
        ],
        name: "TextChanged",
        type: "event"
      },
      %{
        anonymous: false,
        inputs: [
          %{indexed: true, internalType: "bytes32", name: "node", type: "bytes32"},
          %{indexed: false, internalType: "uint64", name: "newVersion", type: "uint64"}
        ],
        name: "VersionChanged",
        type: "event"
      },
      # Functions
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "uint256", name: "contentTypes", type: "uint256"}
        ],
        name: "ABI",
        outputs: [
          %{internalType: "uint256", name: "", type: "uint256"},
          %{internalType: "bytes", name: "", type: "bytes"}
        ],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [%{internalType: "bytes32", name: "node", type: "bytes32"}],
        name: "addr",
        outputs: [%{internalType: "address payable", name: "", type: "address"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "uint256", name: "coinType", type: "uint256"}
        ],
        name: "addr",
        outputs: [%{internalType: "bytes", name: "", type: "bytes"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "address", name: "delegate", type: "address"},
          %{internalType: "bool", name: "approved", type: "bool"}
        ],
        name: "approve",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [%{internalType: "bytes32", name: "node", type: "bytes32"}],
        name: "clearRecords",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [%{internalType: "bytes32", name: "node", type: "bytes32"}],
        name: "contenthash",
        outputs: [%{internalType: "bytes", name: "", type: "bytes"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "bytes32", name: "name", type: "bytes32"},
          %{internalType: "uint16", name: "resource", type: "uint16"}
        ],
        name: "dnsRecord",
        outputs: [%{internalType: "bytes", name: "", type: "bytes"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "bytes32", name: "name", type: "bytes32"}
        ],
        name: "hasDNSRecords",
        outputs: [%{internalType: "bool", name: "", type: "bool"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "bytes4", name: "interfaceID", type: "bytes4"}
        ],
        name: "interfaceImplementer",
        outputs: [%{internalType: "address", name: "", type: "address"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "address", name: "owner", type: "address"},
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "address", name: "delegate", type: "address"}
        ],
        name: "isApprovedFor",
        outputs: [%{internalType: "bool", name: "", type: "bool"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "address", name: "account", type: "address"},
          %{internalType: "address", name: "operator", type: "address"}
        ],
        name: "isApprovedForAll",
        outputs: [%{internalType: "bool", name: "", type: "bool"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [%{internalType: "bytes[]", name: "data", type: "bytes[]"}],
        name: "multicall",
        outputs: [%{internalType: "bytes[]", name: "results", type: "bytes[]"}],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "nodehash", type: "bytes32"},
          %{internalType: "bytes[]", name: "data", type: "bytes[]"}
        ],
        name: "multicallWithNodeCheck",
        outputs: [%{internalType: "bytes[]", name: "results", type: "bytes[]"}],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [%{internalType: "bytes32", name: "node", type: "bytes32"}],
        name: "name",
        outputs: [%{internalType: "string", name: "", type: "string"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [%{internalType: "bytes32", name: "node", type: "bytes32"}],
        name: "pubkey",
        outputs: [
          %{internalType: "bytes32", name: "x", type: "bytes32"},
          %{internalType: "bytes32", name: "y", type: "bytes32"}
        ],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [%{internalType: "bytes32", name: "", type: "bytes32"}],
        name: "recordVersions",
        outputs: [%{internalType: "uint64", name: "", type: "uint64"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "uint256", name: "contentType", type: "uint256"},
          %{internalType: "bytes", name: "data", type: "bytes"}
        ],
        name: "setABI",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "uint256", name: "coinType", type: "uint256"},
          %{internalType: "bytes", name: "a", type: "bytes"}
        ],
        name: "setAddr",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "address", name: "a", type: "address"}
        ],
        name: "setAddr",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "address", name: "operator", type: "address"},
          %{internalType: "bool", name: "approved", type: "bool"}
        ],
        name: "setApprovalForAll",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "bytes", name: "hash", type: "bytes"}
        ],
        name: "setContenthash",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "bytes", name: "data", type: "bytes"}
        ],
        name: "setDNSRecords",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "bytes4", name: "interfaceID", type: "bytes4"},
          %{internalType: "address", name: "implementer", type: "address"}
        ],
        name: "setInterface",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "string", name: "newName", type: "string"}
        ],
        name: "setName",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "bytes32", name: "x", type: "bytes32"},
          %{internalType: "bytes32", name: "y", type: "bytes32"}
        ],
        name: "setPubkey",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "string", name: "key", type: "string"},
          %{internalType: "string", name: "value", type: "string"}
        ],
        name: "setText",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "bytes", name: "hash", type: "bytes"}
        ],
        name: "setZonehash",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
      },
      %{
        inputs: [%{internalType: "bytes4", name: "interfaceID", type: "bytes4"}],
        name: "supportsInterface",
        outputs: [%{internalType: "bool", name: "", type: "bool"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [
          %{internalType: "bytes32", name: "node", type: "bytes32"},
          %{internalType: "string", name: "key", type: "string"}
        ],
        name: "text",
        outputs: [%{internalType: "string", name: "", type: "string"}],
        stateMutability: "view",
        type: "function"
      },
      %{
        inputs: [%{internalType: "bytes32", name: "node", type: "bytes32"}],
        name: "zonehash",
        outputs: [%{internalType: "bytes", name: "", type: "bytes"}],
        stateMutability: "view",
        type: "function"
      }
    ]

    use VeChain.Contract,
      abi: @vns_resolver_abi,
      default_address: @vns_resolver_address
  end
end
