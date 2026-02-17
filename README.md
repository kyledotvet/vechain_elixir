# VeChain Elixir SDK

A comprehensive Elixir SDK for interacting with the VeChainThor blockchain. Built with a composable architecture inspired by the `Req` HTTP client, this SDK provides multiple levels of API for maximum flexibility when needed and ease of use out of the box.

## Current Status

This SDK is currently in early development. The core data structures and transaction encoding/decoding are implemented, but many features are still in progress. The README is being built out alongside the implementation to provide comprehensive documentation and examples.

- [x] [Transaction encoding/decoding](#transaction-encoding-decoding)
- [x] [Building transactions from clauses](#building-a-transaction)
- [x] Signing transactions as sender
- [ ] Reading blockchain data
- [ ] Signing transactions as a gas payer (VIP-191 fee delegation)
- [ ] High-level convenience functions for common operations (e.g. transferring VET/VTHO)
- [ ] Comprehensive test coverage
- [ ] QoL improvements around Async/OTP patterns for transaction lifecycle management
- [ ] Telemetry integration for monitoring transaction lifecycle and performance
- [ ] Detailed documentation and examples


## Installation

Add `vechain` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vechain, "~> 0.0.2"}
  ]
end
```

## Configuration

```elixir
config :vechain,
  network: :mainnet,
  thor_node_url: "https://sync-mainnet.vechain.org/",
  default_expiration: 32,
  default_gas_margin: 0.1,
  default_max_fee_per_gas: 0,
  default_max_priority_fee_per_gas: 0
```

## Understanding Clauses

The handling of transaction clauses is core to VeChain and therefore the SDK as well. Translating desired contract calls to VeChain transaction clauses leverages the work done in the [`elixir_ethers` library](https://hexdocs.pm/ethers) around ABI encoding. Each clause in a VeChain transaction can represent a call to a contract function, and the SDK provides utilities to construct these clauses from their ABI definitions.

### Example: Building a Clause from an ABI-Loaded Contract Function

```json
# path/to/my_contract_abi.json
[
  {
    "constant": false,
    "inputs": [
      {
        "name": "_to",
        "type": "address"
      },
      {
        "name": "_amount",
        "type": "uint256"
      }
    ],
    "name": "transfer",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
```

```elixir
defmodule MyContract do
  use VeChain.Contract,
    abi_file: "path/to/my_contract_abi.json",
    default_address: "0x1234567890abcdef1234567890abcdef12345678"
end
```

```elixir
alias VeChain.Transaction
alias VeChain.Utils
alias VeChain.Transaction.Clause

transfer_clause =
  MyContract.transfer("0xabcdef0123456789abcdef0123456789abcdef01", Utils.to_wei(100))
  |> Clause.from_contract_fn()

Transaction.new()
|> Transaction.append_clause(transfer_clause)
# => %VeChain.Transaction.Eip1559{
#   clauses: [
#     %VeChain.Transaction.Clause{
#       to: "0x1234567890abcdef1234567890abcdef12345678",
#       value: "0x0",
#       data: "0xa9059cbb0000000..."
#     }
#   ],
#.  ...
# }
```

**Further References:**
- `VeChain.Transaction.Clause.from_contract_fn/1` - Convert an ABI-loaded function call (`Ethers.TxData`) to a transaction clause
- `VeChain.Transaction.append_clause/2` - Append a clause to a transaction
- The [Custom ABIs section](https://hexdocs.pm/ethers/readme.html#custom-abis) of the `elixir_ethers` documentation.

## Building a Transaction

The SDK provides a low-level API for building transactions from scratch, which can then be signed and sent to the network. This allows for maximum flexibility in constructing complex transactions with multiple clauses, fee delegation, and more.

```elixir
transaction = VeChain.Transaction.new(
  type: :eip1559,
  network: :mainnet,
  max_priority_fee_per_gas: 0,
  max_fee_per_gas: 0,
  expiration: 32
)
```

## Transaction Encoding/Decoding

The SDK provides functions to encode and decode VeChain transactions. These can be raw transaction data from the blockchain or transactions you want to create and sign.

### Decoding an Existing Transaction

```elixir
# From https://sync-mainnet.vechain.org/transactions/0x29e08ec9784c33aeb9be99e3ff22ace0f285cbc338933379688b866c06713db0?raw=true
# Ref: https://vechainstats.com/transaction/0x29e08ec9784c33aeb9be99e3ff22ace0f285cbc338933379688b866c06713db0/
raw_tx = "0x51f901244a88016da36825315ad964f87af85c940000000000000000000000000000456e6572677980b844095ea7b300000000000000000000000040dc1e247569e4b66b25dda1ae3da6077632d68d0000000000000000000000000000000000000000000000056bc75e2d63100000db9440dc1e247569e4b66b25dda1ae3da6077632d68d80840c43f6d18527b960d782860a9d46cb0f828304a92980843be12077c101b882f0f101b6f8126cd442d54736c71532fda335498dcf59ed1c856d36174a324c9c6572b8355de320b59f0aa3cb122c15bd544374b95c4bd722a6c4232735e8790900190b390cecbadb572cd7862f21c9cb0e27f2b0831554e215ff0660282f6eba124314cd7008ecdd9fab7ab096ea49f9522cc8d751bebef2afc57c2a6c23e46a0601"

transaction = VeChain.Transaction.cast(raw_tx)
# => %VeChain.Transaction.Eip1559{
#      id: "0x29e08ec9784c33aeb9be99e3ff22ace0f285cbc338933379688b866c06713db0",
#      . . .
#    }

encoded_transaction = transaction
  |> VeChain.Transaction.encode(include_signature: true)
  |> VeChain.Utils.hex_encode()
# => "0x51f901244a88016da36825315ad964f87af85c94000000000..."

raw_tx == encoded_transaction
# => true
```

## Resources

- [VeChain Documentation](https://docs.vechain.org/)
- [JavaScript SDK](https://github.com/vechain/vechain-sdk-js)
- [Block Explorer](https://explore.vechain.org/)

## License

[MIT License](LICENSE)

## Acknowledgments

- Inspired by the [Req](https://github.com/wojtekmach/req) HTTP client
- Built on top of the excellent [Elixir Ethers](https://github.com/ExWeb3/elixir_ethers) library
- Built with 💜 for the VeChain community by [kyle.vet](https://kyle.vet)
