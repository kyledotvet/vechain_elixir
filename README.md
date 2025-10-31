# VeChain SDK for Elixir

A comprehensive Elixir SDK for interacting with the VeChainThor blockchain. Built with a composable architecture inspired by the `Req` HTTP client, this SDK provides three levels of API for maximum flexibility and ease of use.

## Features

- 🔗 **Three-level API design**: High-level convenience, mid-level composability, low-level control
- ⚡ **Multi-clause atomic transactions**: Execute multiple operations in a single transaction
- 💸 **VIP-191 fee delegation**: Native support for designated gas payer
- 🔐 **Complete cryptographic operations**: Blake2b hashing, Secp256k1 signing
- 📦 **Built-in contract support**: VTHO, Energy, Params, Executor, Extension
- 🎯 **Type-safe ABI encoding/decoding**: Full contract interaction support
- 🔄 **Transaction encoding/decoding**: Serialize and deserialize VeChain transactions
- 📡 **Thor RESTful API client**: Complete integration with VeChain nodes
- 📊 **Telemetry integration**: Monitor transaction lifecycle and performance
- 🧪 **Comprehensive test coverage**: Unit, property-based, and integration tests

## Key Differences from Ethereum

VeChain is EVM-compatible but has significant differences:

- **Transaction structure**: Completely different from Ethereum
- **Multi-clause transactions**: Multiple operations per transaction (atomic)
- **Fee delegation (VIP-191)**: Gas payer can differ from transaction sender
- **Dual-token model**: VET (value) and VTHO (gas)
- **Blake2b-256 hashing**: Instead of Keccak-256 for transaction hashing
- **Proof of Authority**: Different consensus mechanism
- **Deterministic nonce**: Not based on account state like Ethereum

## Installation

Add `vechain` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vechain, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Transfer VET (High-Level API)

```elixir
# Simple VET transfer
{:ok, receipt} = VeChain.transfer_vet(
  to: "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
  amount: VeChain.Units.vet(10),
  private_key: private_key,
  network: :testnet
)

# Check transaction status
IO.puts("Transaction ID: #{receipt["meta"]["txID"]}")
IO.puts("Gas Used: #{receipt["gasUsed"]}")
IO.puts("Reverted: #{receipt["reverted"]}")
```

### Transfer VTHO

```elixir
{:ok, receipt} = VeChain.transfer_vtho(
  to: "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed",
  amount: VeChain.Units.vtho(100),
  private_key: private_key,
  network: :testnet
)
```

### Multi-Clause Transaction (Mid-Level API)

```elixir
alias VeChain.{Transaction, Clause, Units}

# Create atomic transaction with multiple operations
{:ok, receipt} =
  Transaction.new(network: :testnet)
  |> Transaction.add_clause(
    Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", Units.vet(5))
  )
  |> Transaction.add_clause(
    Clause.transfer_vet("0x1234567890123456789012345678901234567890", Units.vet(3))
  )
  |> Transaction.add_clause(
    Clause.transfer_vtho("0xabcdef0123456789abcdef0123456789abcdef01", Units.vtho(50))
  )
  |> Transaction.run()
  |> Transaction.sign(private_key)
  |> Transaction.broadcast()
  |> Transaction.await_receipt()
```

### Contract Interaction

```elixir
# Read contract state
client = VeChain.Client.Thor.new(network: :testnet)
{:ok, balance} = VeChain.Contracts.VTHO.balance_of(
  client,
  "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
)

IO.puts("VTHO Balance: #{VeChain.Units.to_vtho(balance)}")

# Call custom contract
abi = [
  %{
    "name" => "setValue",
    "type" => "function",
    "inputs" => [%{"type" => "uint256"}],
    "outputs" => []
  }
]

{:ok, receipt} = VeChain.call_contract(
  contract: "0x1234567890123456789012345678901234567890",
  abi: abi,
  function: "setValue",
  args: [42],
  private_key: private_key,
  network: :testnet
)
```

### Deploy Contract

```elixir
bytecode = "0x608060405234801561001057600080fd5b50..."
abi = [
  %{
    "type" => "constructor",
    "inputs" => [%{"type" => "uint256"}]
  }
]

{:ok, receipt} = VeChain.deploy_contract(
  bytecode: bytecode,
  abi: abi,
  args: [1000],
  private_key: private_key,
  network: :testnet
)

contract_address = receipt["outputs"][0]["contractAddress"]
IO.puts("Contract deployed at: #{contract_address}")
```

### Fee Delegation (VIP-191)

```elixir
# Origin creates and signs transaction
tx =
  Transaction.new(network: :testnet)
  |> Transaction.add_clause(Clause.transfer_vet(recipient, Units.vet(1)))
  |> Transaction.enable_vip191()
  |> Transaction.run()
  |> Transaction.sign(origin_private_key)

# Gas payer co-signs
tx_with_delegation = Transaction.co_sign(tx, gas_payer_private_key)

# Broadcast
{:ok, receipt} =
  tx_with_delegation
  |> Transaction.broadcast()
  |> Transaction.await_receipt()
```

### Low-Level Control

```elixir
# Manual transaction construction
alias VeChain.{Transaction, Clause, Reserved}

tx = %Transaction{
  chain_tag: 0x27,  # Testnet
  block_ref: <<0, 255, 236, 184, 170, 187, 204, 221>>,
  expiration: 32,
  clauses: [
    %Clause{
      to: VeChain.Utils.normalize_address("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"),
      value: VeChain.Units.vet(1),
      data: <<>>
    }
  ],
  gas_price_coef: 0,
  gas: 21000,
  depends_on: nil,
  nonce: 12345,
  reserved: %Reserved{features: 0, unused: []},
  signature: nil
}

# Get signing hash
{:ok, signing_hash} = Transaction.get_signing_hash(tx)

# Sign manually
{:ok, signature} = VeChain.Crypto.Secp256k1.sign(signing_hash, private_key)
tx = Transaction.put_signature(tx, signature)

# Encode to RLP
{:ok, encoded} = Transaction.encode(tx)

# Broadcast
client = VeChain.Client.Thor.new(network: :testnet)
{:ok, response} = VeChain.Client.Thor.post_transaction(client, encoded)
```

## API Design

The SDK provides three levels of API for different use cases:

### High-Level API

Convenient functions with sensible defaults. Best for common operations.

```elixir
VeChain.transfer_vet(...)
VeChain.transfer_vtho(...)
VeChain.call_contract(...)
VeChain.deploy_contract(...)
```

### Mid-Level API

Composable transaction building with automatic pipeline steps.

```elixir
Transaction.new()
|> Transaction.add_clause(...)
|> Transaction.run()
|> Transaction.sign(private_key)
|> Transaction.broadcast()
```

### Low-Level API

Manual struct manipulation for advanced use cases.

```elixir
tx = %Transaction{...}
|> Transaction.put_chain_tag(...)
|> Transaction.put_block_ref(...)
```

## Configuration

Configure the SDK in your `config/config.exs`:

```elixir
config :vechain,
  network: :testnet,
  thor_node_url: "https://testnet.veblocks.net",
  default_expiration: 32,
  default_gas_price_coef: 0,
  telemetry_enabled: true
```

Environment-specific configuration in `config/runtime.exs`:

```elixir
config :vechain,
  thor_node_url: System.get_env("VECHAIN_NODE_URL") || "https://testnet.veblocks.net"
```

## Networks

### Mainnet

```elixir
config :vechain, network: :mainnet
```

- Chain Tag: `0x4A`
- Default Node: `https://mainnet.veblocks.net`

### Testnet

```elixir
config :vechain, network: :testnet
```

- Chain Tag: `0x27`
- Default Node: `https://testnet.veblocks.net`
- Faucet: https://faucet.vecha.in/

### Solo (Local Development)

```elixir
config :vechain, network: :solo
```

- Chain Tag: `0xA4`
- Default Node: `http://localhost:8669`

## Telemetry

The SDK emits telemetry events for monitoring and debugging:

```elixir
:telemetry.attach(
  "vechain-handler",
  [:vechain, :transaction, :confirmed],
  fn _event, _measurements, metadata, _config ->
    IO.puts("Transaction confirmed: #{metadata.receipt["meta"]["txID"]}")
  end,
  nil
)
```

Available events:

- `[:vechain, :transaction, :start | :stop | :exception]`
- `[:vechain, :transaction, :sign, :start | :stop]`
- `[:vechain, :transaction, :broadcast, :start | :stop]`
- `[:vechain, :transaction, :confirmed]`
- `[:vechain, :contract, :call, :start | :stop]`
- `[:vechain, :contract, :deploy, :start | :stop]`
- `[:vechain, :http, :request, :start | :stop | :exception]`

See `VeChain.Telemetry` for full documentation.

## Unit Conversion

```elixir
# Convert to wei
VeChain.Units.vet(1)        # => 1_000_000_000_000_000_000
VeChain.Units.vtho(100)     # => 100_000_000_000_000_000_000
VeChain.Units.wei(1000)     # => 1000

# Convert from wei
VeChain.Units.to_vet(1_000_000_000_000_000_000)   # => 1.0
VeChain.Units.to_vtho(100_000_000_000_000_000_000) # => 100.0

# Format for display
VeChain.Units.format_vet(1_000_000_000_000_000_000)     # => "1.0 VET"
VeChain.Units.format_vtho(100_000_000_000_000_000_000)  # => "100.0 VTHO"

# Parse from string
{:ok, amount} = VeChain.Units.parse_vet("1.5 VET")      # => {:ok, 1_500_000_000_000_000_000}
{:ok, amount} = VeChain.Units.parse_vtho("50 VTHO")     # => {:ok, 50_000_000_000_000_000_000}
```

## Address Handling

The SDK uses hex strings with "0x" prefix for all public APIs:

```elixir
# Addresses are hex strings
address = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"

# Validate address
VeChain.Utils.valid_address?(address)  # => true

# Checksum address
VeChain.Utils.checksum_address(address)

# Derive address from private key
{:ok, address} = VeChain.Crypto.Address.from_private_key(private_key)
address_hex = VeChain.Utils.encode_address!(address)
```

## Testing

Run unit tests:

```bash
mix test
```

Run integration tests (requires testnet access):

```bash
mix test --only integration
```

Run all tests:

```bash
mix test --include integration
```

## Documentation

Generate documentation:

```bash
mix docs
```

View documentation:

```bash
open doc/index.html
```

## Examples

See the `examples/` directory for more comprehensive examples:

- `examples/transfer.exs` - VET and VTHO transfers
- `examples/multi_clause.exs` - Atomic multi-clause transactions
- `examples/contract.exs` - Contract deployment and interaction
- `examples/fee_delegation.exs` - VIP-191 fee delegation
- `examples/wallet.exs` - HD wallet and mnemonic management

## Migration from JavaScript SDK

If you're familiar with the VeChain JavaScript SDK, here's a quick comparison:

### JavaScript SDK

```javascript
const transaction = new Transaction({
  chainTag: 0x27,
  blockRef: '0x00000000aabbccdd',
  expiration: 32,
  clauses: [
    {
      to: '0x7567d83b7b8d80addcb281a71d54fc7b3364ffed',
      value: 1000,
      data: '0x'
    }
  ],
  gasPriceCoef: 0,
  gas: 21000,
  dependsOn: null,
  nonce: 12345
});

const signingHash = transaction.signingHash();
const signature = secp256k1.sign(signingHash, privateKey);
transaction.signature = signature;

const raw = transaction.encode();
const response = await thorClient.sendTransaction(raw);
```

### Elixir SDK

```elixir
{:ok, receipt} =
  Transaction.new(chain_tag: 0x27)
  |> Transaction.put_block_ref(<<0, 0, 0, 0, 0xAA, 0xBB, 0xCC, 0xDD>>)
  |> Transaction.put_expiration(32)
  |> Transaction.add_clause(
    Clause.transfer_vet("0x7567d83b7b8d80addcb281a71d54fc7b3364ffed", 1000)
  )
  |> Transaction.put_gas(21000)
  |> Transaction.put_nonce(12345)
  |> Transaction.sign(private_key)
  |> Transaction.broadcast()
  |> Transaction.await_receipt()
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Resources

- [VeChain Documentation](https://docs.vechain.org/)
- [Thor Wiki](https://github.com/vechain/thor/wiki)
- [VIP-191 Specification](https://docs.vechain.org/core-concepts/transactions/meta-transaction-features/designated-gas-payer-vip-191)
- [JavaScript SDK](https://github.com/vechain/vechain-sdk-js)
- [Block Explorer](https://explore.vechain.org/)

## License

[MIT License](LICENSE)

## Acknowledgments

- Inspired by the [Req](https://github.com/wojtekmach/req) HTTP client
- Built with 💜 for the VeChain community by [kyle.vet](https://kyle.vet)
- Special thanks to the VeChain Foundation for their documentation and support
