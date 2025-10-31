defmodule VeChain.Types do
  @moduledoc """
  Common type definitions for VeChain SDK.

  Follows elixir_ethers pattern for type safety. These types define the
  public API format for addresses, hashes, and data.

  ## Type Definitions

  - `t_address/0` - Address as hex string with 0x prefix (42 characters)
  - `t_hash/0` - 32-byte hash as hex string with 0x prefix (66 characters)
  - `t_data/0` - Arbitrary length hex data with 0x prefix

  ## Usage

  These types are used throughout the public API to ensure consistent
  handling of hex-encoded values. Internally, the SDK converts these
  to binary format for RLP encoding and cryptographic operations.

  ## Examples

      # Address type
      address :: VeChain.Types.t_address()
      address = "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"

      # Hash type
      tx_id :: VeChain.Types.t_hash()
      tx_id = "0xabcd1234..." # 32-byte hash

      # Data type
      data :: VeChain.Types.t_data()
      data = "0x1234abcd..." # Arbitrary length
  """

  @typedoc """
  Address as hex string with 0x prefix.

  A VeChain address is a 20-byte value represented as a 42-character
  hex string (0x + 40 hex digits).

  ## Examples

      "0x7567d83b7b8d80addcb281a71d54fc7b3364ffed"
      "0x0000000000000000000000000000456E65726779"  # VTHO contract
  """
  @type t_address :: String.t()

  @typedoc """
  32-byte hash as hex string with 0x prefix.

  Used for transaction IDs, block IDs, and other 32-byte hashes.
  Represented as a 66-character hex string (0x + 64 hex digits).

  ## Examples

      "0xabcd1234567890abcd1234567890abcd1234567890abcd1234567890abcd1234"
  """
  @type t_hash :: String.t()

  @typedoc """
  Arbitrary length hex data with 0x prefix.

  Used for contract call data, signatures, and other binary data.
  Length varies depending on the data being encoded.

  ## Examples

      "0x"                    # Empty data
      "0x1234"                # 2 bytes
      "0xa9059cbb..."         # Function call data
  """
  @type t_data :: String.t()

  @typedoc """
  Transaction ID type alias.

  A transaction ID is a 32-byte hash, so this is an alias for `t_hash/0`.
  """
  @type t_tx_id :: t_hash()

  @typedoc """
  Block ID type alias.

  A block ID is a 32-byte hash, so this is an alias for `t_hash/0`.
  """
  @type t_block_id :: t_hash()
end
