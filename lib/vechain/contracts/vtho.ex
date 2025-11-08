defmodule VeChain.Contracts.VTHO do
  @moduledoc """
  VTHO (VeThor) token contract interface.

  VTHO is VeChain's gas token, generated automatically by holding VET.
  It follows the VIP-180 standard (compatible with ERC-20).

  The VTHO contract is deployed at the same address on all networks:
  `0x0000000000000000000000000000456E65726779`

  ## Examples

      # Get VTHO balance
      iex> VeChain.Contracts.VTHO.balance_of(
      ...>   "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
      ...>   network: :testnet
      ...> )
      {:ok, 1000000000000000000000}

      # Create transfer clause
      iex> clause = VeChain.Contracts.VTHO.transfer(
      ...>   "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
      ...>   1000
      ...> )
      iex> VeChain.Transaction.new()
      ...> |> VeChain.Transaction.add_clause(clause)
      ...> |> VeChain.Transaction.sign(private_key)
      ...> |> VeChain.Transaction.broadcast()
  """

  # VIP-180 (ERC-20 compatible) ABI with VeChain-specific extensions
  # Source: https://github.com/vechain/b32/blob/master/ABIs/energy.json
  @vip180_abi [
    %{
      constant: true,
      inputs: [],
      name: "name",
      outputs: [%{name: "", type: "string"}],
      payable: false,
      stateMutability: "pure",
      type: "function"
    },
    %{
      constant: false,
      inputs: [
        %{name: "_spender", type: "address"},
        %{name: "_value", type: "uint256"}
      ],
      name: "approve",
      outputs: [%{name: "success", type: "bool"}],
      payable: false,
      stateMutability: "nonpayable",
      type: "function"
    },
    %{
      constant: true,
      inputs: [],
      name: "totalSupply",
      outputs: [%{name: "", type: "uint256"}],
      payable: false,
      stateMutability: "view",
      type: "function"
    },
    %{
      constant: false,
      inputs: [
        %{name: "_from", type: "address"},
        %{name: "_to", type: "address"},
        %{name: "_amount", type: "uint256"}
      ],
      name: "transferFrom",
      outputs: [%{name: "success", type: "bool"}],
      payable: false,
      stateMutability: "nonpayable",
      type: "function"
    },
    %{
      constant: true,
      inputs: [],
      name: "decimals",
      outputs: [%{name: "", type: "uint8"}],
      payable: false,
      stateMutability: "pure",
      type: "function"
    },
    %{
      constant: true,
      inputs: [%{name: "_owner", type: "address"}],
      name: "balanceOf",
      outputs: [%{name: "balance", type: "uint256"}],
      payable: false,
      stateMutability: "view",
      type: "function"
    },
    %{
      constant: true,
      inputs: [],
      name: "symbol",
      outputs: [%{name: "", type: "string"}],
      payable: false,
      stateMutability: "pure",
      type: "function"
    },
    %{
      constant: false,
      inputs: [
        %{name: "_to", type: "address"},
        %{name: "_amount", type: "uint256"}
      ],
      name: "transfer",
      outputs: [%{name: "success", type: "bool"}],
      payable: false,
      stateMutability: "nonpayable",
      type: "function"
    },
    %{
      constant: false,
      inputs: [
        %{name: "_from", type: "address"},
        %{name: "_to", type: "address"},
        %{name: "_amount", type: "uint256"}
      ],
      name: "move",
      outputs: [%{name: "success", type: "bool"}],
      payable: false,
      stateMutability: "nonpayable",
      type: "function"
    },
    %{
      constant: true,
      inputs: [],
      name: "totalBurned",
      outputs: [%{name: "", type: "uint256"}],
      payable: false,
      stateMutability: "view",
      type: "function"
    },
    %{
      constant: true,
      inputs: [
        %{name: "_owner", type: "address"},
        %{name: "_spender", type: "address"}
      ],
      name: "allowance",
      outputs: [%{name: "remaining", type: "uint256"}],
      payable: false,
      stateMutability: "view",
      type: "function"
    },
    %{
      anonymous: false,
      inputs: [
        %{indexed: true, name: "_from", type: "address"},
        %{indexed: true, name: "_to", type: "address"},
        %{indexed: false, name: "_value", type: "uint256"}
      ],
      name: "Transfer",
      type: "event"
    },
    %{
      anonymous: false,
      inputs: [
        %{indexed: true, name: "_owner", type: "address"},
        %{indexed: true, name: "_spender", type: "address"},
        %{indexed: false, name: "_value", type: "uint256"}
      ],
      name: "Approval",
      type: "event"
    }
  ]

  use VeChain.Contract,
    abi: @vip180_abi,
    default_address: "0x0000000000000000000000000000456E65726779"

  @doc """
  Get VTHO contract address.

  The address is the same on all networks.

  ## Examples

      iex> VeChain.Contracts.VTHO.address()
      "0x0000000000000000000000000000456E65726779"
  """
  @spec address() :: String.t()
  def address, do: __default_address__()
end
