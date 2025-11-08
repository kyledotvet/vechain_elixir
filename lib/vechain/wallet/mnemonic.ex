defmodule VeChain.Wallet.Mnemonic do
  @moduledoc """
  BIP39 mnemonic generation and validation for VeChain wallets.

  This module provides functionality to:
  - Generate random mnemonic phrases (12, 15, 18, 21, or 24 words)
  - Encode entropy into mnemonic phrases
  - Decode mnemonic phrases back to entropy
  - Validate mnemonic phrases
  - Generate seeds from mnemonics (for HD wallet derivation)

  ## Examples

      # Generate a random 12-word mnemonic
      {:ok, mnemonic} = VeChain.Wallet.Mnemonic.generate()
      # => {:ok, ["army", "van", "defense", ...]}

      # Generate a 24-word mnemonic
      {:ok, mnemonic} = VeChain.Wallet.Mnemonic.generate(24)

      # Validate a mnemonic
      VeChain.Wallet.Mnemonic.valid?(mnemonic)
      # => true

      # Generate seed for HD wallet derivation
      {:ok, seed} = VeChain.Wallet.Mnemonic.to_seed(mnemonic, "optional passphrase")

  ## Reference

  - BIP39 Specification: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
  - Wordlist: https://github.com/bitcoin/bips/blob/master/bip-0039/english.txt
  """

  @wordlist ~w(
    abandon ability able about above absent absorb abstract absurd abuse access accident
    account accuse achieve acid acoustic acquire across act action actor actress actual
    adapt add addict address adjust admit adult advance advice aerobic affair afford
    afraid again age agent agree ahead aim air airport aisle alarm album alcohol
    alert alien all alley allow almost alone alpha already also alter always amateur
    amazing among amount amused analyst anchor ancient anger angle angry animal ankle
    announce annual another answer antenna antique anxiety any apart apology appear
    apple approve april arch arctic area arena argue arm armed armor army around
    arrange arrest arrive arrow art artefact artist artwork ask aspect assault asset
    assist assume asthma athlete atom attack attend attitude attract auction audit
    august aunt author auto autumn average avocado avoid awake aware away awesome
    awful awkward axis baby bachelor bacon badge bag balance balcony ball bamboo
    banana banner bar barely bargain barrel base basic basket battle beach bean
    beauty because become beef before begin behave behind believe below belt bench
    benefit best betray better between beyond bicycle bid bike bind biology bird
    birth bitter black blade blame blanket blast bleak bless blind blood blossom
    blouse blue blur blush board boat body boil bomb bone bonus book boost border
    boring borrow boss bottom bounce box boy bracket brain brand brass brave bread
    breeze brick bridge brief bright bring brisk broccoli broken bronze broom brother
    brown brush bubble buddy budget buffalo build bulb bulk bullet bundle bunker
    burden burger burst bus business busy butter buyer buzz cabbage cabin cable
    cactus cage cake call calm camera camp can canal cancel candy cannon canoe
    canvas canyon capable capital captain car carbon card cargo carpet carry cart
    case cash casino castle casual cat catalog catch category cattle caught cause
    caution cave ceiling celery cement census century cereal certain chair chalk
    champion change chaos chapter charge chase chat cheap check cheese chef cherry
    chest chicken chief child chimney choice choose chronic chuckle chunk churn
    cigar cinnamon circle citizen city civil claim clap clarify claw clay clean
    clerk clever click client cliff climb clinic clip clock clog close cloth cloud
    clown club clump cluster clutch coach coast coconut code coffee coil coin
    collect color column combine come comfort comic common company concert conduct
    confirm congress connect consider control convince cook cool copper copy coral
    core corn correct cost cotton couch country couple course cousin cover coyote
    crack cradle craft cram crane crash crater crawl crazy cream credit creek crew
    cricket crime crisp critic crop cross crouch crowd crucial cruel cruise crumble
    crunch crush cry crystal cube culture cup cupboard curious current curtain curve
    cushion custom cute cycle dad damage damp dance danger daring dash daughter
    dawn day deal debate debris decade december decide decline decorate decrease
    deer defense define defy degree delay deliver demand demise denial dentist deny
    depart depend deposit depth deputy derive describe desert design desk despair
    destroy detail detect develop device devote diagram dial diamond diary dice
    diesel diet differ digital dignity dilemma dinner dinosaur direct dirt disagree
    discover disease dish dismiss disorder display distance divert divide divorce
    dizzy doctor document dog doll dolphin domain donate donkey donor door dose
    double dove draft dragon drama drastic draw dream dress drift drill drink drip
    drive drop drum dry duck dumb dune during dust dutch duty dwarf dynamic eager
    eagle early earn earth easily east easy echo ecology economy edge edit educate
    effort egg eight either elbow elder electric elegant element elephant elevator
    elite else embark embody embrace emerge emotion employ empower empty enable
    enact end endless endorse enemy energy enforce engage engine enhance enjoy
    enlist enough enrich enroll ensure enter entire entry envelope episode equal
    equip era erase erode erosion error erupt escape essay essence estate eternal
    ethics evidence evil evoke evolve exact example excess exchange excite exclude
    excuse execute exercise exhaust exhibit exile exist exit exotic expand expect
    expire explain expose express extend extra eye eyebrow fabric face faculty fade
    faint faith fall false fame family famous fan fancy fantasy farm fashion fat
    fatal father fatigue fault favorite feature february federal fee feed feel
    female fence festival fetch fever few fiber fiction field figure file film
    filter final find fine finger finish fire firm first fiscal fish fit fitness
    fix flag flame flash flat flavor flee flight flip float flock floor flower
    fluid flush fly foam focus fog foil fold follow food foot force forest forget
    fork fortune forum forward fossil foster found fox fragile frame frequent fresh
    friend fringe frog front frost frown frozen fruit fuel fun funny furnace fury
    future gadget gain galaxy gallery game gap garage garbage garden garlic garment
    gas gasp gate gather gauge gaze general genius genre gentle genuine gesture
    ghost giant gift giggle ginger giraffe girl give glad glance glare glass glide
    glimpse globe gloom glory glove glow glue goat goddess gold good goose gorilla
    gospel gossip govern gown grab grace grain grant grape grass gravity great
    green grid grief grit grocery group grow grunt guard guess guide guilt guitar
    gun gym habit hair half hammer hamster hand happy harbor hard harsh harvest
    hat have hawk hazard head health heart heavy hedgehog height hello helmet help
    hen hero hidden high hill hint hip hire history hobby hockey hold hole holiday
    hollow home honey hood hope horn horror horse hospital host hotel hour hover
    hub huge human humble humor hundred hungry hunt hurdle hurry hurt husband hybrid
    ice icon idea identify idle ignore ill illegal illness image imitate immense
    immune impact impose improve impulse inch include income increase index indicate
    indoor industry infant inflict inform inhale inherit initial inject injury
    inmate inner innocent input inquiry insane insect inside inspire install intact
    interest into invest invite involve iron island isolate issue item ivory jacket
    jaguar jar jazz jealous jeans jelly jewel job join joke journey joy judge juice
    jump jungle junior junk just kangaroo keen keep ketchup key kick kid kidney
    kind kingdom kiss kit kitchen kite kitten kiwi knee knife knock know lab label
    labor ladder lady lake lamp language laptop large later latin laugh laundry
    lava law lawn lawsuit layer lazy leader leaf learn leave lecture left leg legal
    legend leisure lemon lend length lens leopard lesson letter level liar liberty
    library license life lift light like limb limit link lion liquid list little
    live lizard load loan lobster local lock logic lonely long loop lottery loud
    lounge love loyal lucky luggage lumber lunar lunch luxury lyrics machine mad
    magic magnet maid mail main major make mammal man manage mandate mango mansion
    manual maple marble march margin marine market marriage mask mass master match
    material math matrix matter maximum maze meadow mean measure meat mechanic
    medal media melody melt member memory mention menu mercy merge merit merry
    mesh message metal method middle midnight milk million mimic mind minimum minor
    minute miracle mirror misery miss mistake mix mixed mixture mobile model modify
    mom moment monitor monkey monster month moon moral more morning mosquito mother
    motion motor mountain mouse move movie much muffin mule multiply muscle museum
    mushroom music must mutual myself mystery myth naive name napkin narrow nasty
    nation nature near neck need negative neglect neither nephew nerve nest net
    network neutral never news next nice night noble noise nominee noodle normal
    north nose notable note nothing notice novel now nuclear number nurse nut oak
    obey object oblige obscure observe obtain obvious occur ocean october odor off
    offer office often oil okay old olive olympic omit once one onion online only
    open opera opinion oppose option orange orbit orchard order ordinary organ
    orient original orphan ostrich other outdoor outer output outside oval oven
    over own owner oxygen oyster ozone pact paddle page pair palace palm panda
    panel panic panther paper parade parent park parrot party pass patch path
    patient patrol pattern pause pave payment peace peanut pear peasant pelican
    pen penalty pencil people pepper perfect permit person pet phone photo phrase
    physical piano picnic picture piece pig pigeon pill pilot pink pioneer pipe
    pistol pitch pizza place planet plastic plate play please pledge pluck plug
    plunge poem poet point polar pole police pond pony pool popular portion position
    possible post potato pottery poverty powder power practice praise predict
    prefer prepare present pretty prevent price pride primary print priority prison
    private prize problem process produce profit program project promote proof
    property prosper protect proud provide public pudding pull pulp pulse pumpkin
    punch pupil puppy purchase purity purpose purse push put puzzle pyramid quality
    quantum quarter question quick quit quiz quote rabbit raccoon race rack radar
    radio rail rain raise rally ramp ranch random range rapid rare rate rather
    raven raw razor ready real reason rebel rebuild recall receive recipe record
    recycle reduce reflect reform refuse region regret regular reject relax release
    relief rely remain remember remind remove render renew rent reopen repair
    repeat replace report require rescue resemble resist resource response result
    retire retreat return reunion reveal review reward rhythm rib ribbon rice rich
    ride ridge rifle right rigid ring riot ripple risk ritual rival river road
    roast robot robust rocket romance roof rookie room rose rotate rough round
    route royal rubber rude rug rule run runway rural sad saddle sadness safe sail
    salad salmon salon salt salute same sample sand satisfy satoshi sauce sausage
    save say scale scan scare scatter scene scheme school science scissors scorpion
    scout scrap screen script scrub sea search season seat second secret section
    security seed seek segment select sell seminar senior sense sentence series
    service session settle setup seven shadow shaft shallow share shed shell sheriff
    shield shift shine ship shiver shock shoe shoot shop short shoulder shove
    shrimp shrug shuffle shy sibling sick side siege sight sign silent silk silly
    silver similar simple since sing siren sister situate six size skate sketch
    ski skill skin skirt skull slab slam sleep slender slice slide slight slim
    slogan slot slow slush small smart smile smoke smooth snack snake snap sniff
    snow soap soccer social sock soda soft solar soldier solid solution solve
    someone song soon sorry sort soul sound soup source south space spare spatial
    spawn speak special speed spell spend sphere spice spider spike spin spirit
    split spoil sponsor spoon sport spot spray spread spring spy square squeeze
    squirrel stable stadium staff stage stairs stamp stand start state stay steak
    steel stem step stereo stick still sting stock stomach stone stool story stove
    strategy street strike strong struggle student stuff stumble style subject
    submit subway success such sudden suffer sugar suggest suit summer sun sunny
    sunset super supply supreme sure surface surge surprise surround survey suspect
    sustain swallow swamp swap swarm swear sweet swift swim swing switch sword
    symbol symptom syrup system table tackle tag tail talent talk tank tape target
    task taste tattoo taxi teach team tell ten tenant tennis tent term test text
    thank that theme then theory there they thing this thought three thrive throw
    thumb thunder ticket tide tiger tilt timber time tiny tip tired tissue title
    toast tobacco today toddler toe together toilet token tomato tomorrow tone
    tongue tonight tool tooth top topic topple torch tornado tortoise toss total
    tourist toward tower town toy track trade traffic tragic train transfer trap
    trash travel tray treat tree trend trial tribe trick trigger trim trip trophy
    trouble truck true truly trumpet trust truth try tube tuition tumble tuna
    tunnel turkey turn turtle twelve twenty twice twin twist two type typical ugly
    umbrella unable unaware uncle uncover under undo unfair unfold unhappy uniform
    unique unit universe unknown unlock until unusual unveil update upgrade uphold
    upon upper upset urban urge usage use used useful useless usual utility vacant
    vacuum vague valid valley valve van vanish vapor various vast vault vehicle
    velvet vendor venture venue verb verify version very vessel veteran viable
    vibrant vicious victory video view village vintage violin virtual virus visa
    visit visual vital vivid vocal voice void volcano volume vote voyage wage wagon
    wait walk wall walnut want warfare warm warrior wash wasp waste water wave way
    wealth weapon wear weasel weather web wedding weekend weird welcome west wet
    whale what wheat wheel when where whip whisper wide width wife wild will win
    window wine wing wink winner winter wire wisdom wise wish witness wolf woman
    wonder wood wool word work world worry worth wrap wreck wrestle wrist write
    wrong yard year yellow you young youth zebra zero zone zoo
  )

  # Create a reverse index map for fast word lookup
  @word_to_index Enum.with_index(@wordlist) |> Map.new()

  @type mnemonic :: [String.t()]
  @type entropy :: binary()
  @type seed :: binary()

  @doc """
  Generate a random mnemonic phrase.

  ## Options

  - `word_count` - Number of words (12, 15, 18, 21, or 24). Default: 12

  ## Examples

      {:ok, mnemonic} = VeChain.Wallet.Mnemonic.generate()
      # => {:ok, ["army", "van", "defense", ...]} (12 words)

      {:ok, mnemonic} = VeChain.Wallet.Mnemonic.generate(24)
      # => {:ok, ["army", "van", ...]} (24 words)

      # Invalid word count
      VeChain.Wallet.Mnemonic.generate(10)
      # => {:error, :invalid_word_count}
  """
  @spec generate(word_count :: 12 | 15 | 18 | 21 | 24) ::
          {:ok, mnemonic()} | {:error, :invalid_word_count}
  def generate(word_count \\ 12)

  def generate(12), do: {:ok, encode!(generate_entropy(128))}
  def generate(15), do: {:ok, encode!(generate_entropy(160))}
  def generate(18), do: {:ok, encode!(generate_entropy(192))}
  def generate(21), do: {:ok, encode!(generate_entropy(224))}
  def generate(24), do: {:ok, encode!(generate_entropy(256))}
  def generate(_), do: {:error, :invalid_word_count}

  @doc """
  Generate a random mnemonic phrase. Raises on error.

  ## Examples

      mnemonic = VeChain.Wallet.Mnemonic.generate!()
      # => ["army", "van", "defense", ...]

      mnemonic = VeChain.Wallet.Mnemonic.generate!(24)
      # => ["army", "van", ...] (24 words)
  """
  @spec generate!(word_count :: 12 | 15 | 18 | 21 | 24) :: mnemonic()
  def generate!(word_count \\ 12) do
    case generate(word_count) do
      {:ok, mnemonic} -> mnemonic
      {:error, reason} -> raise ArgumentError, "Failed to generate mnemonic: #{reason}"
    end
  end

  @doc """
  Encode entropy into a mnemonic phrase.

  Entropy must be 128, 160, 192, 224, or 256 bits (16, 20, 24, 28, or 32 bytes).

  ## Examples

      entropy = :crypto.strong_rand_bytes(16)  # 128 bits
      {:ok, mnemonic} = VeChain.Wallet.Mnemonic.encode(entropy)
      # => {:ok, ["army", "van", ...]} (12 words)

      # Invalid entropy size
      VeChain.Wallet.Mnemonic.encode(<<1, 2, 3>>)
      # => {:error, :invalid_entropy_length}
  """
  @spec encode(entropy()) :: {:ok, mnemonic()} | {:error, :invalid_entropy_length}
  def encode(entropy)
      when is_binary(entropy) and bit_size(entropy) >= 128 and bit_size(entropy) <= 256 and
             rem(bit_size(entropy), 32) == 0 do
    mnemonic =
      entropy
      |> attach_checksum()
      |> map_onto_wordlist()

    {:ok, mnemonic}
  end

  def encode(_), do: {:error, :invalid_entropy_length}

  @doc """
  Encode entropy into a mnemonic phrase. Raises on error.

  ## Examples

      entropy = :crypto.strong_rand_bytes(16)
      mnemonic = VeChain.Wallet.Mnemonic.encode!(entropy)
      # => ["army", "van", ...]
  """
  @spec encode!(entropy()) :: mnemonic()
  def encode!(entropy) do
    case encode(entropy) do
      {:ok, mnemonic} -> mnemonic
      {:error, reason} -> raise ArgumentError, "Failed to encode entropy: #{reason}"
    end
  end

  @doc """
  Decode a mnemonic phrase back to entropy.

  Validates the checksum and returns the original entropy if valid.

  ## Examples

      mnemonic = ["army", "van", "defense", ...]
      {:ok, entropy} = VeChain.Wallet.Mnemonic.decode(mnemonic)
      # => {:ok, <<...>>} (16, 20, 24, 28, or 32 bytes)

      # Invalid checksum
      bad_mnemonic = ["army", "army", "army", ...]
      VeChain.Wallet.Mnemonic.decode(bad_mnemonic)
      # => {:error, :invalid_checksum}

      # Invalid word
      VeChain.Wallet.Mnemonic.decode(["notaword", ...])
      # => {:error, :invalid_word}
  """
  @spec decode(mnemonic()) :: {:ok, entropy()} | {:error, :invalid_checksum | :invalid_word}
  def decode(mnemonic) when is_list(mnemonic) do
    with {:ok, indices} <- map_words_to_indices(mnemonic),
         data_and_checksum <- indices_to_bitstring(indices),
         {:ok, entropy} <- verify_checksum(data_and_checksum) do
      {:ok, entropy}
    end
  end

  @doc """
  Decode a mnemonic phrase back to entropy. Raises on error.

  ## Examples

      mnemonic = ["army", "van", "defense", ...]
      entropy = VeChain.Wallet.Mnemonic.decode!(mnemonic)
      # => <<...>>
  """
  @spec decode!(mnemonic()) :: entropy()
  def decode!(mnemonic) do
    case decode(mnemonic) do
      {:ok, entropy} -> entropy
      {:error, reason} -> raise ArgumentError, "Failed to decode mnemonic: #{reason}"
    end
  end

  @doc """
  Validate a mnemonic phrase.

  Checks if all words are in the wordlist and the checksum is valid.

  ## Examples

      mnemonic = VeChain.Wallet.Mnemonic.generate!()
      VeChain.Wallet.Mnemonic.valid?(mnemonic)
      # => true

      VeChain.Wallet.Mnemonic.valid?(["notaword", "invalid"])
      # => false
  """
  @spec valid?(mnemonic()) :: boolean()
  def valid?(mnemonic) when is_list(mnemonic) do
    case decode(mnemonic) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Convert a mnemonic phrase to a seed for HD wallet derivation.

  The seed is generated using PBKDF2-HMAC-SHA512 with 2048 iterations,
  following the BIP39 specification.

  ## Options

  - `passphrase` - Optional passphrase for additional security. Default: ""

  ## Examples

      mnemonic = VeChain.Wallet.Mnemonic.generate!()
      {:ok, seed} = VeChain.Wallet.Mnemonic.to_seed(mnemonic)
      # => {:ok, <<...>>} (64 bytes)

      # With passphrase
      {:ok, seed} = VeChain.Wallet.Mnemonic.to_seed(mnemonic, "my secret passphrase")
      # => {:ok, <<...>>}
  """
  @spec to_seed(mnemonic(), passphrase :: String.t()) :: {:ok, seed()}
  def to_seed(mnemonic, passphrase \\ "") when is_list(mnemonic) and is_binary(passphrase) do
    # Join mnemonic words with spaces
    mnemonic_string = Enum.join(mnemonic, " ")

    # Salt is "mnemonic" + passphrase
    salt = "mnemonic" <> passphrase

    # PBKDF2-HMAC-SHA512 with 2048 iterations
    seed = pbkdf2_hmac_sha512(mnemonic_string, salt, 2048, 64)

    {:ok, seed}
  end

  @doc """
  Convert a mnemonic phrase to a seed. Raises on error.

  ## Examples

      mnemonic = VeChain.Wallet.Mnemonic.generate!()
      seed = VeChain.Wallet.Mnemonic.to_seed!(mnemonic)
      # => <<...>> (64 bytes)
  """
  @spec to_seed!(mnemonic(), passphrase :: String.t()) :: seed()
  def to_seed!(mnemonic, passphrase \\ "") do
    {:ok, seed} = to_seed(mnemonic, passphrase)
    seed
  end

  @doc """
  Derive a private key from mnemonic words using a derivation path.

  This is a convenience function that combines seed generation, master key
  creation, and path derivation to directly extract the private key.

  ## Parameters

  - `words` - List of mnemonic words
  - `path` - BIP32/BIP44 derivation path (default: "m/44'/818'/0'/0/0")
  - `passphrase` - Optional passphrase for seed generation (default: "")

  ## Examples

      words = ["ignore", "empty", "bird", ...]
      {:ok, private_key} = VeChain.Wallet.Mnemonic.to_private_key(words)
      # => {:ok, <<...>>} (32 bytes)

      # With custom path
      {:ok, private_key} = VeChain.Wallet.Mnemonic.to_private_key(words, "m/0/1")

      # With passphrase
      {:ok, private_key} = VeChain.Wallet.Mnemonic.to_private_key(words, "m/44'/818'/0'/0/0", "secret")
  """
  @spec to_private_key(mnemonic(), derivation_path :: String.t(), passphrase :: String.t()) ::
          {:ok, binary()} | {:error, term()}
  def to_private_key(words, path \\ "m/44'/818'/0'/0/0", passphrase \\ "")
      when is_list(words) and is_binary(path) and is_binary(passphrase) do
    alias VeChain.Wallet.HD

    # Validate mnemonic before processing
    if not valid?(words) do
      {:error, :invalid_mnemonic}
    else
      with {:ok, seed} <- to_seed(words, passphrase),
           {:ok, master_key} <- HD.master_key_from_seed(seed),
           {:ok, derived_key} <- HD.derive(master_key, path) do
        {:ok, HD.private_key(derived_key)}
      end
    end
  end

  @doc """
  Derive a private key from mnemonic words. Raises on error.

  ## Examples

      words = ["ignore", "empty", "bird", ...]
      private_key = VeChain.Wallet.Mnemonic.to_private_key!(words)
      # => <<...>> (32 bytes)
  """
  @spec to_private_key!(mnemonic(), derivation_path :: String.t(), passphrase :: String.t()) ::
          binary()
  def to_private_key!(words, path \\ "m/44'/818'/0'/0/0", passphrase \\ "") do
    case to_private_key(words, path, passphrase) do
      {:ok, private_key} -> private_key
      {:error, reason} ->
        raise ArgumentError, "Failed to derive private key from mnemonic: #{reason}"
    end
  end

  # Private functions

  defp generate_entropy(bits) do
    bytes = div(bits, 8)
    :crypto.strong_rand_bytes(bytes)
  end

  defp attach_checksum(entropy) do
    hash = :crypto.hash(:sha256, entropy)
    checksum_bits = div(bit_size(entropy), 32)
    <<checksum::bits-size(checksum_bits), _::bits>> = hash
    <<entropy::bits, checksum::bits>>
  end

  defp map_onto_wordlist(bits) do
    for <<chunk::11 <- bits>> do
      Enum.at(@wordlist, chunk)
    end
  end

  defp map_words_to_indices(words) do
    indices =
      Enum.map(words, fn word ->
        Map.get(@word_to_index, word)
      end)

    if Enum.any?(indices, &is_nil/1) do
      {:error, :invalid_word}
    else
      {:ok, indices}
    end
  end

  defp indices_to_bitstring(indices) do
    Enum.reduce(indices, <<>>, fn index, acc ->
      <<acc::bits, index::11>>
    end)
  end

  defp verify_checksum(data_and_checksum) do
    total_bits = bit_size(data_and_checksum)
    entropy_bits = div(total_bits * 32, 33)
    checksum_bits = total_bits - entropy_bits

    # Ensure we have valid bit sizes
    if rem(entropy_bits, 8) != 0 or checksum_bits <= 0 do
      {:error, :invalid_checksum}
    else
      <<entropy::bits-size(entropy_bits), provided_checksum::bits-size(checksum_bits)>> =
        data_and_checksum

      # Convert bitstring to binary for hashing
      entropy_binary = <<entropy::bits>>

      # Only hash if we have a proper byte-aligned binary
      if rem(bit_size(entropy_binary), 8) == 0 do
        <<expected_checksum::bits-size(checksum_bits), _::bits>> =
          :crypto.hash(:sha256, entropy_binary)

        if provided_checksum == expected_checksum do
          {:ok, entropy_binary}
        else
          {:error, :invalid_checksum}
        end
      else
        {:error, :invalid_checksum}
      end
    end
  end

  # PBKDF2-HMAC-SHA512 implementation
  defp pbkdf2_hmac_sha512(password, salt, iterations, key_length) do
    # Number of blocks needed
    blocks_needed = div(key_length + 63, 64)

    # Generate each block
    blocks =
      for block_index <- 1..blocks_needed do
        generate_block(password, salt, iterations, block_index)
      end

    # Concatenate and truncate to desired length
    blocks
    |> IO.iodata_to_binary()
    |> binary_part(0, key_length)
  end

  defp generate_block(password, salt, iterations, block_index) do
    # Initial U1 = HMAC(password, salt || block_index)
    initial = hmac_sha512(password, <<salt::binary, block_index::32>>)

    # U2 through Un
    {_last, result} =
      Enum.reduce(2..iterations, {initial, initial}, fn _i, {prev, acc} ->
        next = hmac_sha512(password, prev)
        {next, :crypto.exor(acc, next)}
      end)

    result
  end

  defp hmac_sha512(key, data) do
    :crypto.mac(:hmac, :sha512, key, data)
  end
end
