defmodule VeChain.Utils do
  @moduledoc """
  Utility functions specific to VeChain. All other generic utilities are delegated from `Ethers.Utils`.
  """
  alias Ethers.Types

  @spec decode_address(Types.t_address() | nil) :: {:ok, binary()} | {:error, :invalid_address}
  defdelegate decode_address(arg), to: Ethers.Utils

  @spec decode_address!(Types.t_address() | nil) :: binary() | no_return()
  defdelegate decode_address!(arg), to: Ethers.Utils

  @spec encode_address(binary()) :: {:ok, Types.t_address()} | {:error, :invalid_address}
  defdelegate encode_address(arg), to: Ethers.Utils

  @spec encode_address!(binary()) :: Types.t_address() | no_return()
  defdelegate encode_address!(arg), to: Ethers.Utils

  @spec from_wei(integer()) :: float()
  defdelegate from_wei(arg), to: Ethers.Utils

  @spec hex_decode(String.t()) :: {:ok, binary()} | :error
  defdelegate hex_decode(arg), to: Ethers.Utils

  @spec hex_decode!(String.t()) :: binary() | no_return()
  defdelegate hex_decode!(arg), to: Ethers.Utils

  @spec hex_to_integer(String.t()) :: {:ok, non_neg_integer()} | {:error, :invalid_hex}
  defdelegate hex_to_integer(arg), to: Ethers.Utils

  @spec hex_to_integer!(String.t()) :: non_neg_integer() | no_return()
  defdelegate hex_to_integer!(arg), to: Ethers.Utils

  @spec human_arg(term(), ABI.FunctionSelector.type()) :: term()
  defdelegate human_arg(bin, type), to: Ethers.Utils

  @spec integer_to_hex(non_neg_integer()) :: String.t()
  defdelegate integer_to_hex(arg), to: Ethers.Utils

  @spec prepare_arg(term(), ABI.FunctionSelector.type()) :: term()
  defdelegate prepare_arg(bin, type), to: Ethers.Utils

  # TODO: Validate these functions are consistent with VeChain usage
  # defdelegate public_key_to_address(arg), to: Ethers.Utils
  # defdelegate public_key_to_address(arg1, arg2), to: Ethers.Utils

  @spec remove_leading_zeros(binary()) :: binary()
  defdelegate remove_leading_zeros(arg), to: Ethers.Utils

  @spec to_checksum_address(Types.t_address() | <<_::320>>, pos_integer() | nil) ::
          Types.t_address()
  defdelegate to_checksum_address(addr, chain_id \\ nil), to: Ethers.Utils

  @spec to_wei(number()) :: integer()
  defdelegate to_wei(arg), to: Ethers.Utils

  @spec valid_checksum_address?(Types.t_address()) :: boolean()
  defdelegate valid_checksum_address?(arg), to: Ethers.Utils

  @doc """
  Encode to hex with 0x prefix.

  ## Examples

      iex> VeChain.Utils.hex_encode("VeChain_ex")
      "0x5665436861696e5f6578"
  """
  @spec hex_encode(binary() | nil, boolean()) :: String.t()
  def hex_encode(bin, include_prefix \\ true)
  def hex_encode(nil, _), do: nil
  # TODO: Check if this is needed SDK-wide or just for clause value encoding
  def hex_encode(<<0>>, include_prefix), do: if(include_prefix, do: "0x0", else: "0")

  def hex_encode(bin, include_prefix),
    do: if(include_prefix, do: "0x", else: "") <> Base.encode16(bin, case: :lower)

  @doc """
  Decodes hex to binary, returns nil if input is an empty binary or nil.

  ## Examples

      iex> VeChain.Utils.maybe_hex_decode(nil)
      nil

      iex> VeChain.Utils.maybe_hex_decode(<<>>)
      nil

      iex> VeChain.Utils.maybe_hex_decode("0x1234")
      <<0x12, 0x34>>
  """
  @spec maybe_hex_decode(String.t() | nil) :: binary() | nil
  def maybe_hex_decode(nil), do: nil
  def maybe_hex_decode(<<>>), do: nil
  def maybe_hex_decode(hex), do: hex_decode!(hex)

  @doc """
  Encodes an address to hex, returns nil if input is nil.
  """
  @spec maybe_encode_address(Types.t_address() | nil) :: String.t() | nil
  def maybe_encode_address(nil), do: nil
  def maybe_encode_address(<<>>), do: nil
  def maybe_encode_address(<<addr::binary-size(20)>>), do: encode_address!(addr)

  @doc """
  Generates a transaction nonce.

  VeChain uses deterministic nonce generation based on timestamp and randomness.
  The nonce is an 8-byte (64-bit) value.

  ## Returns

  8-byte nonce value (integer).

  ## Examples

      iex> nonce = VeChain.Utils.generate_nonce()
      iex> is_integer(nonce) and nonce >= 0
      true
  """
  @spec generate_nonce() :: non_neg_integer()
  def generate_nonce do
    # Use current timestamp (milliseconds) + random bytes
    timestamp = System.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> :binary.decode_unsigned(:big)

    # Combine timestamp and random for uniqueness
    rem(timestamp * 1000 + random, 0xFFFFFFFFFFFFFFFF)
  end

  @spec decompress_block_ref(binary()) :: binary()
  def decompress_block_ref(binary) when byte_size(binary) >= 8, do: binary

  def decompress_block_ref(binary) when byte_size(binary) < 8,
    do: decompress_block_ref(<<0, binary::binary>>)

  @spec nullable_hex_encode(binary() | nil) :: String.t() | nil
  def nullable_hex_encode(<<>>), do: nil
  def nullable_hex_encode(value), do: hex_encode(value)

  @spec drop_leading_zeros(String.t()) :: String.t()
  def drop_leading_zeros("0x0"), do: "0x0"
  def drop_leading_zeros("0x0" <> rest), do: drop_leading_zeros("0x" <> rest)
  def drop_leading_zeros(hex_bin), do: hex_bin
end
