defmodule VeChain.Transaction.Signature do
  alias VeChain.Transaction

  def maybe_parse(%{signature: nil} = transaction), do: transaction
  def maybe_parse(transaction), do: parse(transaction)

  def parse(
        %{signature: <<sig_first_half::binary-size(65), sig_last_half::binary-size(65)>>} =
          transaction
      ) do
    # Having a sig length of 130 (65 + 65) means that the tx was signed twice and therefore had a delegated gas payer.
    origin_address =
      transaction
      |> Transaction.hash()
      |> recover_public_key(sig_first_half)
      |> maybe_inflate_pubkey()
      |> derive_address_from_public_key()

    gas_payer_address =
      transaction
      |> Transaction.hash(origin_address)
      |> recover_public_key(sig_last_half)
      |> maybe_inflate_pubkey()
      |> derive_address_from_public_key()

    %{transaction | origin: origin_address, delegator: gas_payer_address}
  end

  def parse(%{signature: <<signature::binary-size(65)>>} = transaction) do
    # A sig length of 65 means that the tx was signed once and therefore the sender was also the gas payer

    origin_address =
      transaction
      |> Transaction.hash()
      |> recover_public_key(signature)
      |> maybe_inflate_pubkey()
      |> derive_address_from_public_key()

    %{transaction | origin: origin_address}
  end

  @spec recover_public_key(binary(), <<_::520>>) :: binary()
  def recover_public_key(
        transaction_hash,
        <<sig::binary-size(64), recovery_byte::binary-size(1)>>
      ) do
    {:ok, pubkey} =
      ExSecp256k1.recover_compact(transaction_hash, sig, :binary.decode_unsigned(recovery_byte))

    pubkey
  end

  def derive_address_from_public_key(<<4, pubkey::binary-size(64)>>) do
    # The public key is the last 64 bytes of the signature (after the recovery byte)
    pubkey
    |> ExKeccak.hash_256()
    |> binary_part(12, 20)
  end

  def maybe_inflate_pubkey(<<4, _rest::binary-size(64)>> = pubkey), do: pubkey

  def maybe_inflate_pubkey(pubkey) do
    # TODO: Need to understand how this should look in Elixir:
    # const x = publicKey.slice(0, 33);
    # const p = nc_secp256k1.ProjectivePoint.fromAffine(
    #     nc_secp256k1.ProjectivePoint.fromHex(
    #         HexUInt.of(x).digits
    #     ).toAffine()
    # );
    # return p.toRawBytes(false);
    pubkey
  end

  @spec maybe_include_signature(list(), Transaction.t(), boolean()) :: list()
  def maybe_include_signature(rlp_list, _tx, false), do: rlp_list

  def maybe_include_signature(rlp_list, %{signature: signature}, true),
    do: rlp_list ++ [signature]
end
