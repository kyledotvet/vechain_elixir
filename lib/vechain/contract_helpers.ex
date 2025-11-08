defmodule VeChain.ContractHelpers do
  @moduledoc false
  # Private helper functions for VeChain.Contract module

  require Logger

  @doc """
  Read ABI from options.

  Accepts either `:abi` or `:abi_file` option.

  ## Returns

  `{abi, file_path}` tuple where file_path is nil if ABI was provided directly.
  """
  @spec read_abi(keyword()) :: {abi :: list(), file_path :: String.t() | nil}
  def read_abi(opts) do
    case Keyword.take(opts, [:abi, :abi_file]) do
      [{type, data}] ->
        do_read_abi(type, data, nil)

      _ ->
        raise ArgumentError,
              "Invalid arguments. Specify either `:abi` or `:abi_file` option"
    end
  end

  @doc """
  Generate function argument AST nodes.

  Creates properly named arguments based on ABI input names or generic arg1, arg2, etc.
  """
  @spec generate_arguments(module(), non_neg_integer(), [String.t()]) :: [Macro.t()]
  def generate_arguments(mod, arity, names) when is_integer(arity) do
    args = Macro.generate_arguments(arity, mod)

    if length(names) >= length(args) do
      args
      |> Enum.zip(names)
      |> Enum.map(&get_argument_name_ast/1)
    else
      args
    end
  end

  @doc """
  Generate error argument keys (atoms).
  """
  @spec generate_error_arguments(module(), non_neg_integer(), [String.t()]) :: [atom()]
  def generate_error_arguments(mod, arity, names) do
    generate_arguments(mod, arity, names)
    |> Enum.map(fn {arg, _ctx, _mod} -> arg end)
  end

  @doc """
  Generate typespec AST for function parameters.

  Handles function overloading by creating union types.
  """
  @spec generate_typespecs([ABI.FunctionSelector.t()]) :: [Macro.t()]
  def generate_typespecs(selectors) do
    Enum.map(selectors, & &1.types)
    |> do_generate_typespecs()
  end

  @doc """
  Generate typespec AST for event parameters (indexed only).
  """
  @spec generate_event_typespecs([ABI.FunctionSelector.t()], non_neg_integer()) :: [Macro.t()]
  def generate_event_typespecs(selectors, arity) do
    Enum.map(selectors, &Enum.take(&1.types, arity))
    |> do_generate_typespecs(true)
  end

  @doc """
  Generate typespec AST for return values.
  """
  @spec generate_return_typespecs([ABI.FunctionSelector.t()]) :: Macro.t()
  def generate_return_typespecs(selectors) do
    return_types =
      Enum.map(selectors, & &1.returns)
      |> Enum.uniq()

    case return_types do
      [[]] ->
        quote(do: nil)

      [[single_type]] ->
        to_elixir_type(single_type)

      [types] when length(types) > 1 ->
        # Create a proper tuple typespec: {type1, type2, ...}
        type_specs = Enum.map(types, &to_elixir_type/1)
        {:{}, [], type_specs}

      _multiple ->
        quote(do: term())
    end
  end

  @doc """
  Generate struct typespec for error types.
  """
  @spec generate_struct_typespecs([atom()], ABI.FunctionSelector.t()) :: Macro.t()
  def generate_struct_typespecs(args, selector) do
    types = Enum.map(selector.types, &to_elixir_type/1)

    # Quoted expression: %__MODULE__{key: type(), ...}
    {:%, [], [{:__MODULE__, [], Elixir}, {:%{}, [], Enum.zip(args, types)}]}
  end

  @doc """
  Aggregate input names across overloaded functions.

  If multiple functions have different names for the same parameter position,
  combines them with "_or_".
  """
  @spec aggregate_input_names([map()]) :: [String.t()]
  def aggregate_input_names([%{type: :event} | _] = selectors) do
    Enum.map(selectors, fn selector ->
      Enum.zip(selector.input_names, selector.inputs_indexed)
      |> Enum.filter(&elem(&1, 1))
      |> Enum.map(&elem(&1, 0))
    end)
    |> Enum.zip_with(&(Enum.uniq(&1) |> Enum.join("_or_")))
  end

  def aggregate_input_names(selectors) do
    Enum.map(selectors, & &1.input_names)
    |> Enum.zip_with(&(Enum.uniq(&1) |> Enum.join("_or_")))
  end

  @doc """
  Find the correct function selector based on arguments.

  Handles function overloading and type matching.
  """
  @spec find_selector!([ABI.FunctionSelector.t()], [term()]) ::
          {ABI.FunctionSelector.t(), [term()]}
  def find_selector!(selectors, args) do
    filtered_selectors = Enum.filter(selectors, &selector_match?(&1, args))

    case filtered_selectors do
      [] ->
        signatures = Enum.map_join(selectors, "\n", &human_signature/1)

        raise ArgumentError, """
        No function selector matches current arguments!

        ## Arguments
        #{inspect(args)}

        ## Available signatures
        #{signatures}
        """

      [selector] ->
        {selector, strip_typed_args(args)}

      selectors ->
        signatures = Enum.map_join(selectors, "\n", &human_signature/1)

        raise ArgumentError, """
        Ambiguous parameters - multiple signatures match

        ## Arguments
        #{inspect(args)}

        ## Possible signatures
        #{signatures}
        """
    end
  end

  @doc """
  Check if a selector matches the given arguments.
  """
  @spec selector_match?(ABI.FunctionSelector.t(), [term()]) :: boolean()
  def selector_match?(%{type: :event} = selector, args) do
    event_indexed_types(selector)
    |> do_selector_match?(args, true)
  end

  def selector_match?(selector, args) do
    do_selector_match?(selector.types, args, false)
  end

  @doc """
  Encode event topics for filtering.

  Returns a list of topic hashes, with nil for non-filtered indexed parameters.
  """
  @spec encode_event_topics(ABI.FunctionSelector.t(), [term()]) :: [String.t() | nil]
  def encode_event_topics(selector, args) do
    [event_topic_0(selector) | encode_event_sub_topics(selector, args)]
  end

  @doc """
  Generate human-readable function signature.
  """
  @spec human_signature(ABI.FunctionSelector.t() | [ABI.FunctionSelector.t()]) :: String.t()
  def human_signature(%ABI.FunctionSelector{
        input_names: names,
        types: types,
        function: function
      }) do
    args =
      if is_list(names) and length(types) == length(names) do
        Enum.zip(types, names)
      else
        types
      end
      |> Enum.map_join(", ", fn
        {type, name} when is_binary(name) and name != "" ->
          "#{ABI.FunctionSelector.encode_type(type)} #{name}"

        type ->
          "#{ABI.FunctionSelector.encode_type(type)}"
      end)

    "#{function}(#{args})"
  end

  def human_signature(selectors) when is_list(selectors) do
    Enum.map_join(selectors, " OR ", &human_signature/1)
  end

  @doc """
  Document types for function parameters.
  """
  @spec document_types([term()], [String.t()]) :: String.t()
  def document_types(types, names \\ []) do
    if length(types) <= length(names) do
      Enum.zip(types, names)
    else
      types
    end
    |> Enum.map_join("\n", fn
      {type, ""} ->
        " - `#{inspect(type)}`"

      {type, name} when is_binary(name) or is_atom(name) ->
        " - `#{name}`: `#{inspect(type)}`"

      type ->
        " - `#{inspect(type)}`"
    end)
  end

  @doc """
  Document help message based on state mutability.
  """
  @spec document_help_message([ABI.FunctionSelector.t()]) :: String.t()
  def document_help_message(selectors) do
    selectors
    |> Enum.map(& &1.state_mutability)
    |> Enum.uniq()
    |> do_document_help_message()
  end

  @doc """
  Document function parameters.
  """
  @spec document_parameters([ABI.FunctionSelector.t()]) :: String.t()
  def document_parameters([%{types: []}]), do: ""

  def document_parameters([%{type: :event} | _] = selectors) do
    parameters_docs =
      Enum.map_join(selectors, "\n\n### OR\n", fn selector ->
        {types, names} =
          Enum.zip(selector.types, selector.input_names)
          |> Enum.zip(selector.inputs_indexed)
          |> Enum.filter(&elem(&1, 1))
          |> Enum.map(&elem(&1, 0))
          |> Enum.unzip()

        document_types(types, names)
      end)

    """
    ## Event Indexed Parameters

    #{parameters_docs}
    """
  end

  def document_parameters(selectors) do
    parameters_docs =
      Enum.map_join(selectors, "\n\n### OR\n", &document_types(&1.types, &1.input_names))

    """
    ## Parameters

    #{parameters_docs}
    """
  end

  @doc """
  Document function return types.
  """
  @spec document_returns([ABI.FunctionSelector.t()]) :: String.t()
  def document_returns([%{type: :event} | _] = selectors) do
    return_type_docs =
      selectors
      |> Enum.map(fn selector ->
        Enum.zip([selector.types, selector.input_names, selector.inputs_indexed])
        |> Enum.reject(&elem(&1, 2))
        |> Enum.map(fn {type, name, false} -> {type, name} end)
        |> Enum.unzip()
      end)
      |> Enum.uniq()
      |> Enum.map_join("\n\n### OR\n", fn
        {[], _input_names} ->
          "This event does not contain any data values!"

        {types, input_names} ->
          document_types(types, input_names)
      end)

    """
    ## Event Data (Non-indexed)

    These are non-indexed values returned in the event log data.

    #{return_type_docs}
    """
  end

  def document_returns(selectors) when is_list(selectors) do
    return_type_docs =
      selectors
      |> Enum.uniq_by(& &1.returns)
      |> Enum.map_join("\n\n### OR\n", fn selector ->
        if Enum.count(selector.returns) > 0 do
          document_types(selector.returns, selector.return_names || [])
        else
          "This function does not return any values."
        end
      end)

    """
    ## Returns

    #{return_type_docs}
    """
  end

  ## Private Helpers

  defp do_read_abi(:abi, abi, file_path) when is_list(abi), do: {abi, file_path}

  defp do_read_abi(:abi, %{"abi" => abi}, file_path), do: do_read_abi(:abi, abi, file_path)

  defp do_read_abi(:abi, abi, file_path) when is_binary(abi) do
    decoded = Jason.decode!(abi)
    do_read_abi(:abi, decoded, file_path)
  end

  defp do_read_abi(:abi_file, file, _file_path) do
    abi = File.read!(file) |> Jason.decode!()
    {abi, file}
  end

  defp get_argument_name_ast({ast, name}) do
    get_argument_name_ast(ast, String.trim(name))
  end

  defp get_argument_name_ast(ast, "_" <> name), do: get_argument_name_ast(ast, name)
  defp get_argument_name_ast(ast, ""), do: ast

  defp get_argument_name_ast({_orig, ctx, md}, name) when is_binary(name) do
    name_atom = String.to_atom(Macro.underscore(name))
    {name_atom, ctx, md}
  end

  defp do_generate_typespecs(types, optional? \\ false) do
    Enum.zip_with(types, & &1)
    |> Enum.map(fn type_group ->
      type_group
      |> Enum.map(&to_elixir_type/1)
      |> Enum.uniq()
      |> then(&if(optional?, do: [nil | &1], else: &1))
      |> Enum.reduce(fn type, acc ->
        quote do
          unquote(type) | unquote(acc)
        end
      end)
    end)
  end

  defp do_selector_match?(types, args, allow_nil) do
    if Enum.count(types) == Enum.count(args) do
      Enum.zip(types, args)
      |> Enum.all?(fn
        {_type, {:typed, _assigned_type, _arg}} -> true
        {_type, nil} -> allow_nil == true
        {type, arg} -> matches_type?(arg, type)
      end)
    else
      false
    end
  end

  defp strip_typed_args(args) do
    Enum.map(args, fn
      {:typed, _type, arg} -> arg
      arg -> arg
    end)
  end

  defp event_topic_0(%{method_id: method_id}) when byte_size(method_id) == 32 do
    "0x" <> Base.encode16(method_id, case: :lower)
  end

  defp event_topic_0(selector) do
    selector
    |> ABI.FunctionSelector.encode()
    |> ExKeccak.hash_256()
    |> then(&("0x" <> Base.encode16(&1, case: :lower)))
  end

  defp encode_event_sub_topics(selector, raw_args) do
    event_indexed_types(selector)
    |> Enum.zip(raw_args)
    |> Enum.map(fn {type, value} -> do_encode_indexed_type(type, value) end)
  end

  defp do_encode_indexed_type(_, nil), do: nil

  defp do_encode_indexed_type(type, value) when type in [:string, :bytes] do
    value
    |> prepare_indexed_arg(type)
    |> ExKeccak.hash_256()
    |> then(&("0x" <> Base.encode16(&1, case: :lower)))
  end

  defp do_encode_indexed_type({:array, _, _} = type, value), do: hashed_encode(type, value)

  defp do_encode_indexed_type({:array, subtype}, value) do
    hashed_encode({:array, subtype, Enum.count(value)}, value)
  end

  defp do_encode_indexed_type({:tuple, _} = type, value), do: hashed_encode(type, value)

  defp do_encode_indexed_type(type, value) do
    [prepare_indexed_arg(value, type)]
    |> ABI.TypeEncoder.encode([type])
    |> then(&("0x" <> Base.encode16(&1, case: :lower)))
  end

  defp hashed_encode(type, value) do
    [prepare_indexed_arg(value, type)]
    |> ABI.TypeEncoder.encode([type])
    |> ExKeccak.hash_256()
    |> then(&("0x" <> Base.encode16(&1, case: :lower)))
  end

  defp event_indexed_types(selector) do
    Enum.zip(selector.types, selector.inputs_indexed)
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  defp prepare_indexed_arg(value, :address) when is_binary(value) do
    if String.starts_with?(value, "0x") do
      VeChain.Utils.decode_address!(value)
    else
      value
    end
  end

  defp prepare_indexed_arg(value, _type), do: value

  defp matches_type?(value, :address) when is_binary(value) do
    VeChain.Utils.valid_address?(value)
  end

  defp matches_type?(value, :bool) when is_boolean(value), do: true
  defp matches_type?(value, :string) when is_binary(value), do: true
  defp matches_type?(value, :bytes) when is_binary(value), do: true
  defp matches_type?(value, {:bytes, _}) when is_binary(value), do: true
  defp matches_type?(value, {:uint, _}) when is_integer(value) and value >= 0, do: true
  defp matches_type?(value, {:int, _}) when is_integer(value), do: true

  defp matches_type?(value, {:array, inner_type}) when is_list(value) do
    Enum.all?(value, &matches_type?(&1, inner_type))
  end

  defp matches_type?(value, {:array, inner_type, _size}) when is_list(value) do
    Enum.all?(value, &matches_type?(&1, inner_type))
  end

  defp matches_type?(_value, _type), do: true

  defp to_elixir_type(:address), do: quote(do: String.t())
  defp to_elixir_type(:bool), do: quote(do: boolean())
  defp to_elixir_type(:string), do: quote(do: String.t())
  defp to_elixir_type(:bytes), do: quote(do: binary())
  defp to_elixir_type({:bytes, _}), do: quote(do: binary())
  defp to_elixir_type({:uint, _}), do: quote(do: non_neg_integer())
  defp to_elixir_type({:int, _}), do: quote(do: integer())

  defp to_elixir_type({:array, type}) do
    quote(do: [unquote(to_elixir_type(type))])
  end

  defp to_elixir_type({:array, type, _size}) do
    quote(do: [unquote(to_elixir_type(type))])
  end

  defp to_elixir_type({:tuple, types}) when is_list(types) do
    # Create a proper tuple typespec: {type1, type2, ...}
    type_specs = Enum.map(types, &to_elixir_type/1)
    {:{}, [], type_specs}
  end

  defp to_elixir_type(_), do: quote(do: term())

  defp do_document_help_message([state_mutability]) do
    message =
      case state_mutability do
        sm when sm in [:pure, :view] ->
          """
          This is a view/pure function. It will execute a contract call and return the result.
          """

        :non_payable ->
          """
          This function returns a clause for use in transactions.
          No VET can be sent with this transaction.
          """

        :payable ->
          """
          This function returns a clause for use in transactions.
          VET can be sent with this transaction.
          """

        nil ->
          """
          This function returns a clause for use in transactions.
          """
      end

    """
    #{message}

    State mutability: `#{inspect(state_mutability)}`
    """
  end

  defp do_document_help_message(state_mutabilities) do
    """
    This function has multiple state mutabilities based on overloading.

    State mutabilities: #{Enum.map_join(state_mutabilities, " OR ", &"`#{inspect(&1)}`")}
    """
  end
end
