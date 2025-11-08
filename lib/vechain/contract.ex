defmodule VeChain.Contract do
  @moduledoc """
  Dynamically creates contract modules from ABIs at compile time.

  This module provides a macro-based interface for defining smart contract
  interactions in a type-safe, documented manner. It automatically generates
  functions for all contract methods, events, and errors based on the ABI.

  ## How to Use

  You can create a new contract module by calling `use VeChain.Contract` with
  the desired parameters:

  ```elixir
  # Using an ABI file
  defmodule MyProject.ERC20 do
    use VeChain.Contract, abi_file: "priv/abis/erc20.json"
  end

  # Providing a default address
  defmodule MyProject.VTHO do
    use VeChain.Contract,
      abi_file: "priv/abis/energy.json",
      default_address: "0x0000000000000000000000000000456E65726779"
  end

  # Using an ABI directly
  defmodule MyProject.Custom do
    use VeChain.Contract,
      abi: [
        %{"inputs" => [], "type" => "constructor"},
        %{
          "inputs" => [%{"name" => "to", "type" => "address"}],
          "name" => "transfer",
          "outputs" => [%{"name" => "", "type" => "bool"}],
          "type" => "function"
        }
      ]
  end
  ```

  ## Generated Functions

  After defining your contract module, functions are automatically generated:

  ### View Functions (read-only)

  View and pure functions automatically execute contract calls and return results:

  ```elixir
  # Returns {:ok, balance} or {:error, reason}
  {:ok, balance} = MyProject.ERC20.balance_of("0x...")

  # Pass options for network, block, etc.
  {:ok, symbol} = MyProject.ERC20.symbol(network: :testnet)
  {:ok, name} = MyProject.ERC20.name(block: "best")
  ```

  ### Transaction Functions (write)

  Non-view functions return `VeChain.Clause` structs for inclusion in transactions:

  ```elixir
  # Create a clause
  clause = MyProject.ERC20.transfer("0x...", 1000)

  # Add to transaction and execute
  VeChain.Transaction.new()
  |> VeChain.Transaction.add_clause(clause)
  |> VeChain.Transaction.sign(private_key)
  |> VeChain.Transaction.broadcast()
  ```

  ### Constructor

  If the ABI includes a constructor, a `constructor/N` function is generated:

  ```elixir
  # Encode constructor parameters for deployment
  encoded = MyContract.constructor("MyToken", "MTK", 18)

  # Use in deployment
  VeChain.deploy_contract(bytecode <> encoded, ...)
  ```

  ### Event Filters

  Events are accessible through a nested `EventFilters` module:

  ```elixir
  # Create event filter
  filter = MyProject.ERC20.EventFilters.transfer(
    from: "0x...",  # Filter specific address
    to: nil          # Any address
  )

  # Get logs
  {:ok, logs} = VeChain.Client.Thor.get_logs(client, filter)
  ```

  ## Valid `use` Options

  - `:abi` - The decoded (or JSON string) ABI of the contract
  - `:abi_file` - File path to the JSON ABI file
  - `:default_address` - Default contract address (optional)
  - `:skip_docs` - Control documentation generation (default: false)
    - `true` - Skip docs for all functions
    - `false` - Generate docs for all functions
    - `[function_name: true/false]` - Control per function

  ## Helper Functions

  Every generated contract module includes:

  - `__default_address__/0` - Returns the default address (or nil)
  - `__abi__/0` - Returns the parsed ABI specification
  - `__events__/0` - Returns all event selectors (via EventFilters module)

  ## Type Safety

  Generated functions include proper typespecs and will validate inputs
  at runtime. Address parameters are validated, and type mismatches will
  raise helpful errors.

  ## Documentation

  All generated functions include:
  - Function signature in human-readable format
  - Parameter types and names
  - Return types
  - State mutability information
  - Usage examples

  ## Function Overloading

  If a contract has multiple functions with the same name but different
  parameters (overloading), the generated function will automatically
  select the correct variant based on the arguments provided.
  """

  require Logger
  require VeChain.ContractHelpers

  import VeChain.ContractHelpers

  @default_constructor %{
    type: :constructor,
    arity: 0,
    selectors: [
      %ABI.FunctionSelector{
        function: nil,
        method_id: nil,
        type: :constructor,
        inputs_indexed: nil,
        state_mutability: nil,
        input_names: [],
        types: [],
        returns: []
      }
    ]
  }

  @doc false
  defmacro __using__(opts) do
    compiler_module = __MODULE__

    quote do
      @before_compile unquote(compiler_module)
      Module.put_attribute(__MODULE__, :_vechain_contract_opts, unquote(opts))
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    module = env.module

    opts = Module.get_attribute(module, :_vechain_contract_opts)

    {abi, abi_file} = read_abi(opts)
    default_address = Keyword.get(opts, :default_address)
    skip_docs = Keyword.get(opts, :skip_docs, false)

    # Parse ABI into function selectors
    function_selectors = ABI.parse_specification(abi, include_events?: true)

    # Group by function name, arity, and type
    function_selectors_with_meta =
      function_selectors
      |> Enum.group_by(fn
        %{type: :event} = f ->
          # For events, count indexed inputs
          {f.function, Enum.count(f.inputs_indexed, & &1), f.type}

        f ->
          # For functions, count all inputs
          {f.function, Enum.count(f.types), f.type}
      end)
      |> Enum.map(fn {{function, arity, type}, selectors} ->
        %{
          selectors: selectors,
          function: function,
          arity: arity,
          type: type
        }
      end)

    # Detect function name conflicts (overloading by arity)
    function_names_with_multiple_arities =
      function_selectors_with_meta
      |> Enum.filter(&(&1.type == :function))
      |> Enum.group_by(& &1.function)
      |> Enum.filter(fn {_name, groups} -> length(groups) > 1 end)
      |> Enum.map(fn {name, _groups} -> name end)
      |> MapSet.new()

    impl_opts = [
      skip_docs: skip_docs,
      has_overloads: function_names_with_multiple_arities
    ]

    # Generate constructor
    constructor_ast =
      function_selectors_with_meta
      |> Enum.find(@default_constructor, &(&1.type == :constructor))
      |> impl(module, impl_opts)

    # Generate contract functions
    functions_ast =
      function_selectors_with_meta
      |> Enum.filter(&(&1.type == :function and not is_nil(&1.function)))
      |> Enum.map(&impl(&1, module, impl_opts))

    # Generate events module
    events_mod_name = Module.concat(module, EventFilters)
    events = Enum.filter(function_selectors_with_meta, &(&1.type == :event))
    events_impl = Enum.map(events, &impl(&1, module, impl_opts))
    event_selectors = Enum.flat_map(events, & &1.selectors)

    # External resource for hot reloading
    external_resource_ast =
      if abi_file do
        quote do
          @external_resource unquote(abi_file)
        end
      end

    events_module_ast =
      quote context: module do
        defmodule unquote(events_mod_name) do
          @moduledoc """
          Event filters for `#{inspect(unquote(module))}`.

          This module provides functions to create event filters for querying
          contract event logs. Each function corresponds to an event defined
          in the contract ABI.
          """

          unquote(external_resource_ast)

          defdelegate __default_address__, to: unquote(module)
          unquote(events_impl)

          @doc "Returns all event selectors for this contract"
          def __events__, do: unquote(Macro.escape(event_selectors))
        end
      end

    # Generate errors module
    errors_mod_name = Module.concat(module, Errors)

    error_modules_ast =
      function_selectors_with_meta
      |> Enum.filter(&(&1.type == :error))
      |> Enum.map(&impl(&1, module, impl_opts))

    errors_module_impl = errors_impl(function_selectors_with_meta, module)

    errors_module_ast =
      quote context: module do
        defmodule unquote(errors_mod_name) do
          @moduledoc false

          unquote(external_resource_ast)

          unquote(error_modules_ast)
          unquote(errors_module_impl)
        end
      end

    # Default address type
    default_address_type =
      if default_address do
        quote do: String.t()
      else
        quote do: nil
      end

    # Module-level helpers
    extra_ast =
      quote context: module do
        unquote(external_resource_ast)

        @doc """
        Returns the default address of the contract.

        Returns `nil` if no default address was specified.
        To specify a default address, see `VeChain.Contract` options.

        ## Examples

            iex> MyContract.__default_address__()
            "0x0000000000000000000000000000456E65726779"
        """
        @spec __default_address__() :: unquote(default_address_type)
        def __default_address__, do: unquote(default_address)

        @doc """
        Returns the parsed ABI specification for this contract.

        ## Examples

            iex> selectors = MyContract.__abi__()
            iex> Enum.find(selectors, & &1.function == "transfer")
        """
        @spec __abi__() :: [ABI.FunctionSelector.t()]
        def __abi__, do: unquote(Macro.escape(function_selectors))

        # Private helper functions for encoding/decoding

        defp prepare_arg(value, :address) when is_binary(value) do
          if String.starts_with?(value, "0x") do
            VeChain.Utils.decode_address!(value)
          else
            value
          end
        end

        defp prepare_arg(value, {:array, :address}) when is_list(value) do
          Enum.map(value, &prepare_arg(&1, :address))
        end

        defp prepare_arg(value, _type), do: value

        defp decode_return_values(selector, data) do
          binary =
            if is_binary(data) and String.starts_with?(data, "0x") do
              case Base.decode16(String.slice(data, 2..-1//1), case: :mixed) do
                {:ok, bin} -> bin
                :error -> data
              end
            else
              data
            end

          try do
            decoded = ABI.TypeDecoder.decode(binary, selector.returns)
            formatted = format_decoded_values(selector.returns, decoded)
            {:ok, formatted}
          rescue
            error -> {:error, error}
          end
        end

        defp format_decoded_values(types, values) do
          types
          |> Enum.zip(values)
          |> Enum.map(fn {type, value} -> format_decoded_value(type, value) end)
        end

        defp format_decoded_value(:address, value)
             when is_binary(value) and byte_size(value) == 20 do
          VeChain.Utils.encode_address!(value)
        end

        defp format_decoded_value({:array, :address}, values) when is_list(values) do
          Enum.map(values, &format_decoded_value(:address, &1))
        end

        defp format_decoded_value(_type, value), do: value
      end

    [extra_ast, constructor_ast | functions_ast] ++ [events_module_ast, errors_module_ast]
  end

  ## Implementation Helpers

  # Constructor implementation
  defp impl(%{type: :constructor, selectors: [selector]} = abi, mod, opts) do
    func_args = generate_arguments(mod, abi.arity, selector.input_names)

    func_input_types =
      selector.types
      |> Enum.map(&to_elixir_type/1)

    quote context: mod, location: :keep do
      if unquote(generate_docs?(:constructor, opts[:skip_docs])) do
        @doc """
        Prepares contract constructor values for deployment.

        To deploy a contract, encode the constructor parameters and append
        them to the contract bytecode.

        ## Parameters
        #{unquote(document_types(selector.types, selector.input_names))}

        ## Returns

        Binary encoded constructor parameters.
        """
        @spec constructor(unquote_splicing(func_input_types)) :: binary()
      end

      def constructor(unquote_splicing(func_args)) do
        args =
          unquote(func_args)
          |> Enum.zip(unquote(Macro.escape(selector.types)))
          |> Enum.map(fn {arg, type} -> prepare_arg(arg, type) end)

        data =
          unquote(Macro.escape(selector))
          |> ABI.encode(args)

        "0x" <> Base.encode16(data, case: :lower)
      end
    end
  end

  # Function implementation (view and non-payable)
  defp impl(%{type: :function} = abi, mod, opts) do
    name =
      abi.function
      |> Macro.underscore()
      |> String.to_atom()

    aggregated_input_names = aggregate_input_names(abi.selectors)
    func_args = generate_arguments(mod, abi.arity, aggregated_input_names)
    func_input_types = generate_typespecs(abi.selectors)

    # Determine if this is a view function
    is_view_function =
      abi.selectors
      |> Enum.all?(&(&1.state_mutability in [:view, :pure]))

    if is_view_function do
      impl_view_function(name, abi, func_args, func_input_types, mod, opts)
    else
      impl_transaction_function(name, abi, func_args, func_input_types, mod, opts)
    end
  end

  # View function - executes call and returns result
  defp impl_view_function(name, abi, func_args, func_input_types, mod, opts) do
    return_types = generate_return_typespecs(abi.selectors)

    # Create a unique variable name for opts to avoid conflicts
    opts_var = Macro.var(:opts, mod)

    # Check if this function has overloads (multiple arities)
    has_overloads = MapSet.member?(opts[:has_overloads] || MapSet.new(), abi.function)

    # Only add default argument if there are no overloads
    final_func_args =
      if has_overloads do
        func_args ++ [opts_var]
      else
        func_args ++ [quote(do: unquote(opts_var) \\ [])]
      end

    final_func_input_types = func_input_types ++ [quote(do: keyword())]

    quote context: mod, location: :keep do
      if unquote(generate_docs?(name, opts[:skip_docs])) do
        @doc """
        Calls `#{unquote(human_signature(abi.selectors))}` on the contract.

        This is a view function that executes a contract call and returns the result.

        #{unquote(document_help_message(abi.selectors))}

        #{unquote(document_parameters(abi.selectors))}

        #{unquote(document_returns(abi.selectors))}

        ## Options

        - `:network` - Network to use (`:mainnet`, `:testnet`)
        - `:client` - Custom Thor client
        - `:block` - Block reference (default: "best")
        - `:address` - Contract address (overrides default)

        ## Examples

            iex> #{inspect(unquote(mod))}.#{unquote(name)}(...)
            {:ok, result}
        """
        @spec unquote(name)(unquote_splicing(final_func_input_types)) ::
                {:ok, unquote(return_types)} | {:error, term()}
      end

      def unquote(name)(unquote_splicing(final_func_args)) do
        {selector, raw_args} =
          find_selector!(unquote(Macro.escape(abi.selectors)), unquote(func_args))

        args =
          Enum.zip(raw_args, selector.types)
          |> Enum.map(fn {arg, type} -> prepare_arg(arg, type) end)

        # Encode function call
        data = ABI.encode(selector, args)

        # Get contract address
        address = Keyword.get(unquote(opts_var), :address) || __default_address__()

        unless address do
          raise VeChain.Error.ContractError,
            message:
              "No contract address specified. Provide :address option or set default_address."
        end

        # Execute contract call
        client = Keyword.get(unquote(opts_var), :client) || VeChain.Client.Thor.default_client()

        with {:ok, result} <-
               VeChain.Client.Thor.call_contract(client, address, data, unquote(opts_var)),
             {:ok, decoded} <- decode_return_values(selector, result["data"]) do
          # Return single value or tuple of values
          case decoded do
            [single] -> {:ok, single}
            multiple -> {:ok, List.to_tuple(multiple)}
          end
        end
      end
    end
  end

  # Transaction function - returns clause
  defp impl_transaction_function(name, abi, func_args, func_input_types, mod, opts) do
    # Create a unique variable name for opts to avoid conflicts
    opts_var = Macro.var(:opts, mod)

    # Check if this function has overloads (multiple arities)
    has_overloads = MapSet.member?(opts[:has_overloads] || MapSet.new(), abi.function)

    # Only add default argument if there are no overloads
    final_func_args =
      if has_overloads do
        func_args ++ [opts_var]
      else
        func_args ++ [quote(do: unquote(opts_var) \\ [])]
      end

    final_func_input_types = func_input_types ++ [quote(do: keyword())]

    quote context: mod, location: :keep do
      if unquote(generate_docs?(name, opts[:skip_docs])) do
        @doc """
        Creates a clause for `#{unquote(human_signature(abi.selectors))}`.

        This function returns a `VeChain.Clause` that can be added to a transaction.

        #{unquote(document_help_message(abi.selectors))}

        #{unquote(document_parameters(abi.selectors))}

        ## Returns

        A `VeChain.Clause` struct that can be added to a transaction.

        ## Options

        - `:address` - Contract address (overrides default)
        - `:value` - Amount of VET to send with the transaction (default: 0)

        ## Examples

            iex> clause = #{inspect(unquote(mod))}.#{unquote(name)}(...)
            iex> VeChain.Transaction.new()
            ...> |> VeChain.Transaction.add_clause(clause)
            ...> |> VeChain.Transaction.sign(private_key)
            ...> |> VeChain.Transaction.broadcast()

            # With custom address
            iex> clause = #{inspect(unquote(mod))}.#{unquote(name)}(..., address: "0x...")
        """
        @spec unquote(name)(unquote_splicing(final_func_input_types)) ::
                VeChain.Clause.t()
      end

      def unquote(name)(unquote_splicing(final_func_args)) do
        {selector, raw_args} =
          find_selector!(unquote(Macro.escape(abi.selectors)), unquote(func_args))

        args =
          Enum.zip(raw_args, selector.types)
          |> Enum.map(fn {arg, type} -> prepare_arg(arg, type) end)

        data = ABI.encode(selector, args)
        hex_data = "0x" <> Base.encode16(data, case: :lower)

        address = Keyword.get(unquote(opts_var), :address) || __default_address__()

        unless address do
          raise VeChain.Error.ContractError,
            message:
              "No contract address specified. Provide :address option or set default_address."
        end

        value = Keyword.get(unquote(opts_var), :value, 0)

        VeChain.Clause.call_contract(address, value, hex_data)
      end
    end
  end

  # Event implementation
  defp impl(%{type: :event} = abi, mod, opts) do
    name =
      abi.function
      |> Macro.underscore()
      |> String.to_atom()

    aggregated_input_names = aggregate_input_names(abi.selectors)
    func_args = generate_arguments(mod, abi.arity, aggregated_input_names)
    func_typespec = generate_event_typespecs(abi.selectors, abi.arity)

    quote context: mod, location: :keep do
      if unquote(generate_docs?(name, opts[:skip_docs])) do
        @doc """
        Creates an event filter for `#{unquote(human_signature(abi.selectors))}`.

        For each indexed parameter, you can either pass a value to filter by,
        or `nil` to match any value.

        #{unquote(document_parameters(abi.selectors))}

        #{unquote(document_returns(abi.selectors))}

        ## Returns

        An event filter struct that can be used with `VeChain.Client.Thor.get_logs/2`.

        ## Examples

            iex> filter = #{inspect(unquote(mod))}.EventFilters.#{unquote(name)}(...)
            iex> {:ok, logs} = VeChain.Client.Thor.get_logs(client, filter)
        """
        @spec unquote(name)(unquote_splicing(func_typespec)) :: map()
      end

      def unquote(name)(unquote_splicing(func_args)) do
        {selector, raw_args} =
          find_selector!(unquote(Macro.escape(abi.selectors)), unquote(func_args))

        topics = encode_event_topics(selector, raw_args)
        address = __default_address__()

        %{
          topics: topics,
          address: address,
          selector: selector
        }
      end
    end
  end

  # Error implementation
  defp impl(%{type: :error, selectors: [selector_abi]} = abi, mod, _opts) do
    error_module = Module.concat([mod, Errors, abi.function])
    aggregated_arg_names = aggregate_input_names(abi.selectors)
    error_args = generate_error_arguments(mod, abi.arity, aggregated_arg_names)
    error_typespec = generate_struct_typespecs(error_args, selector_abi)

    error_module_functions =
      quote context: error_module, location: :keep do
        @doc false
        def decode(data) do
          decoded_args = ABI.decode(function_selector(), data)
          struct_args = Enum.zip(ordered_argument_keys(), decoded_args)
          {:ok, struct!(__MODULE__, struct_args)}
        end

        @doc false
        def function_selector, do: unquote(Macro.escape(selector_abi))

        @doc false
        def ordered_argument_keys, do: unquote(error_args)
      end

    quote context: mod, location: :keep do
      defmodule unquote(error_module) do
        @moduledoc "Error struct for `error #{unquote(abi.function)}`"

        defstruct unquote(error_args)

        @type t :: unquote(error_typespec)

        unquote(error_module_functions)
      end
    end
  end

  # Errors module implementation
  defp errors_impl(selectors, mod) do
    errors_module = Module.concat([mod, Errors])

    error_mappings =
      Enum.filter(selectors, &(&1.type == :error))
      |> Enum.map(fn %{selectors: [selector]} -> selector end)
      |> Enum.map(&{&1.method_id, Module.concat([mod, Errors, &1.function])})
      |> Enum.into(%{})
      |> Macro.escape()

    quote context: errors_module, location: :keep do
      @doc false
      def find_and_decode(<<error_id::binary-4, _::binary>> = error_data) do
        case Map.fetch(error_mappings(), error_id) do
          {:ok, module} -> module.decode(error_data)
          :error -> {:error, :undefined_error}
        end
      end

      defp error_mappings, do: unquote(error_mappings)
    end
  end

  # Documentation control
  defp generate_docs?(_name, true = _skip_docs), do: false
  defp generate_docs?(_name, false = _skip_docs), do: true
  defp generate_docs?(_name, nil = _skip_docs), do: true

  defp generate_docs?(name, skip_docs) when is_list(skip_docs) do
    case Keyword.get(skip_docs, name) do
      nil -> true
      false -> true
      true -> false
    end
  end

  # Type conversion helpers
  defp to_elixir_type(:address), do: quote(do: String.t())
  defp to_elixir_type(:bool), do: quote(do: boolean())
  defp to_elixir_type(:string), do: quote(do: String.t())
  defp to_elixir_type(:bytes), do: quote(do: binary())
  defp to_elixir_type({:bytes, _}), do: quote(do: binary())
  defp to_elixir_type({:uint, _}), do: quote(do: non_neg_integer())
  defp to_elixir_type({:int, _}), do: quote(do: integer())
  defp to_elixir_type({:array, type}), do: quote(do: [unquote(to_elixir_type(type))])
  defp to_elixir_type({:array, type, _size}), do: quote(do: [unquote(to_elixir_type(type))])
  defp to_elixir_type(_), do: quote(do: term())
end
