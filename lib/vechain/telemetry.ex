defmodule VeChain.Telemetry do
  @moduledoc """
  Telemetry integration for VeChain SDK.

  This module provides helpers for emitting and handling telemetry events
  throughout the transaction lifecycle.

  ## Events

  The VeChain SDK emits the following telemetry events:

  ### Transaction Events

  - `[:vechain, :transaction, :start]` - Emitted when a transaction pipeline starts
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{transaction: Transaction.t()}`

  - `[:vechain, :transaction, :stop]` - Emitted when a transaction pipeline completes
    - Measurements: `%{duration: native_time(), system_time: integer()}`
    - Metadata: `%{transaction: Transaction.t(), result: term()}`

  - `[:vechain, :transaction, :exception]` - Emitted when a transaction pipeline errors
    - Measurements: `%{duration: native_time(), system_time: integer()}`
    - Metadata: `%{transaction: Transaction.t(), kind: atom(), reason: term(), stacktrace: list()}`

  ### Transaction Step Events

  - `[:vechain, :transaction, :sign, :start]` - Emitted when transaction signing starts
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{transaction: Transaction.t()}`

  - `[:vechain, :transaction, :sign, :stop]` - Emitted when transaction signing completes
    - Measurements: `%{duration: native_time(), system_time: integer()}`
    - Metadata: `%{transaction: Transaction.t()}`

  - `[:vechain, :transaction, :broadcast, :start]` - Emitted when broadcasting starts
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{transaction: Transaction.t()}`

  - `[:vechain, :transaction, :broadcast, :stop]` - Emitted when broadcasting completes
    - Measurements: `%{duration: native_time(), system_time: integer()}`
    - Metadata: `%{transaction: Transaction.t(), tx_id: binary()}`

  - `[:vechain, :transaction, :confirmed]` - Emitted when transaction is confirmed
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{transaction: Transaction.t(), receipt: map()}`

  ### Contract Events

  - `[:vechain, :contract, :call, :start]` - Emitted when contract call starts
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{contract: binary(), function: String.t(), args: list()}`

  - `[:vechain, :contract, :call, :stop]` - Emitted when contract call completes
    - Measurements: `%{duration: native_time(), system_time: integer()}`
    - Metadata: `%{contract: binary(), function: String.t(), result: term()}`

  - `[:vechain, :contract, :deploy, :start]` - Emitted when contract deployment starts
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{bytecode_size: integer()}`

  - `[:vechain, :contract, :deploy, :stop]` - Emitted when contract deployment completes
    - Measurements: `%{duration: native_time(), system_time: integer()}`
    - Metadata: `%{contract_address: binary()}`

  ### HTTP Client Events

  - `[:vechain, :http, :request, :start]` - Emitted when HTTP request starts
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{method: atom(), url: String.t()}`

  - `[:vechain, :http, :request, :stop]` - Emitted when HTTP request completes
    - Measurements: `%{duration: native_time(), system_time: integer()}`
    - Metadata: `%{method: atom(), url: String.t(), status: integer()}`

  - `[:vechain, :http, :request, :exception]` - Emitted when HTTP request errors
    - Measurements: `%{duration: native_time(), system_time: integer()}`
    - Metadata: `%{method: atom(), url: String.t(), kind: atom(), reason: term()}`

  ## Usage

  ### Attaching Event Handlers

      :telemetry.attach(
        "vechain-transaction-handler",
        [:vechain, :transaction, :confirmed],
        &MyApp.handle_transaction_confirmed/4,
        nil
      )

      def handle_transaction_confirmed(_event, measurements, metadata, _config) do
        Logger.info("Transaction confirmed",
          tx_id: metadata.receipt["meta"]["txID"],
          gas_used: metadata.receipt["gasUsed"]
        )
      end

  ### Using with telemetry_metrics

      defmodule MyApp.Telemetry do
        use Supervisor
        import Telemetry.Metrics

        def start_link(arg) do
          Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
        end

        def init(_arg) do
          children = [
            {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
            {TelemetryMetricsPrometheus, metrics: metrics()}
          ]

          Supervisor.init(children, strategy: :one_for_one)
        end

        defp metrics do
          [
            # Transaction metrics
            counter("vechain.transaction.start.count"),
            counter("vechain.transaction.stop.count"),
            counter("vechain.transaction.exception.count"),
            distribution("vechain.transaction.stop.duration",
              unit: {:native, :millisecond}
            ),

            # Broadcast metrics
            counter("vechain.transaction.broadcast.start.count"),
            counter("vechain.transaction.broadcast.stop.count"),
            distribution("vechain.transaction.broadcast.stop.duration",
              unit: {:native, :millisecond}
            ),

            # HTTP metrics
            counter("vechain.http.request.start.count"),
            counter("vechain.http.request.stop.count",
              tags: [:method, :status]
            ),
            distribution("vechain.http.request.stop.duration",
              unit: {:native, :millisecond},
              tags: [:method]
            )
          ]
        end
      end

  ## Configuration

  Telemetry events can be disabled globally:

      config :vechain,
        telemetry_enabled: false

  Or selectively by event prefix:

      config :vechain,
        telemetry_enabled: true,
        telemetry_disabled_events: [
          [:vechain, :http]
        ]
  """

  @type event_name :: [atom(), ...]
  @type measurements :: map()
  @type metadata :: map()

  @doc """
  Execute telemetry event with span (start/stop/exception pattern).

  Automatically handles timing and emits start, stop, and exception events.

  ## Examples

      VeChain.Telemetry.span(
        [:vechain, :transaction, :sign],
        %{transaction: tx},
        fn ->
          # Sign transaction
          {:ok, signed_tx}
        end
      )
  """
  @spec span(event_name(), metadata(), (() -> result)) :: result when result: term()
  def span(event_prefix, metadata, func) do
    if telemetry_enabled?(event_prefix) do
      start_time = System.monotonic_time()
      start_metadata = Map.put(metadata, :telemetry_span_context, start_time)

      emit(event_prefix ++ [:start], %{system_time: System.system_time()}, start_metadata)

      try do
        result = func.()
        duration = System.monotonic_time() - start_time

        emit(
          event_prefix ++ [:stop],
          %{duration: duration, system_time: System.system_time()},
          Map.put(metadata, :result, result)
        )

        result
      rescue
        exception ->
          duration = System.monotonic_time() - start_time

          emit(
            event_prefix ++ [:exception],
            %{duration: duration, system_time: System.system_time()},
            Map.merge(metadata, %{
              kind: :error,
              reason: exception,
              stacktrace: __STACKTRACE__
            })
          )

          reraise exception, __STACKTRACE__
      catch
        kind, reason ->
          duration = System.monotonic_time() - start_time

          emit(
            event_prefix ++ [:exception],
            %{duration: duration, system_time: System.system_time()},
            Map.merge(metadata, %{
              kind: kind,
              reason: reason,
              stacktrace: __STACKTRACE__
            })
          )

          :erlang.raise(kind, reason, __STACKTRACE__)
      end
    else
      func.()
    end
  end

  @doc """
  Emit a telemetry event.

  ## Examples

      VeChain.Telemetry.emit(
        [:vechain, :transaction, :confirmed],
        %{system_time: System.system_time()},
        %{transaction: tx, receipt: receipt}
      )
  """
  @spec emit(event_name(), measurements(), metadata()) :: :ok
  def emit(event_name, measurements, metadata) do
    if telemetry_enabled?(event_name) do
      :telemetry.execute(event_name, measurements, metadata)
    end

    :ok
  end

  @doc """
  Check if telemetry is enabled for a given event.

  ## Examples

      iex> VeChain.Telemetry.telemetry_enabled?([:vechain, :transaction, :start])
      true
  """
  @spec telemetry_enabled?(event_name()) :: boolean()
  def telemetry_enabled?(event_name) do
    global_enabled? = Application.get_env(:vechain, :telemetry_enabled, true)

    if global_enabled? do
      disabled_events = Application.get_env(:vechain, :telemetry_disabled_events, [])
      not Enum.any?(disabled_events, &event_matches?(&1, event_name))
    else
      false
    end
  end

  @doc """
  Attach a telemetry handler for VeChain events.

  This is a convenience wrapper around `:telemetry.attach/4`.

  ## Examples

      VeChain.Telemetry.attach(
        "my-handler",
        [:vechain, :transaction, :confirmed],
        &MyApp.handle_event/4
      )
  """
  @spec attach(
          handler_id :: String.t() | atom(),
          event_name(),
          handler :: (event_name(), measurements(), metadata(), term() -> any()),
          config :: term()
        ) :: :ok | {:error, :already_exists}
  def attach(handler_id, event_name, handler, config \\ nil) do
    :telemetry.attach(handler_id, event_name, handler, config)
  end

  @doc """
  Attach a telemetry handler for multiple VeChain events.

  This is a convenience wrapper around `:telemetry.attach_many/4`.

  ## Examples

      VeChain.Telemetry.attach_many(
        "my-handler",
        [
          [:vechain, :transaction, :start],
          [:vechain, :transaction, :stop]
        ],
        &MyApp.handle_event/4
      )
  """
  @spec attach_many(
          handler_id :: String.t() | atom(),
          [event_name()],
          handler :: (event_name(), measurements(), metadata(), term() -> any()),
          config :: term()
        ) :: :ok | {:error, :already_exists}
  def attach_many(handler_id, event_names, handler, config \\ nil) do
    :telemetry.attach_many(handler_id, event_names, handler, config)
  end

  @doc """
  Detach a telemetry handler.

  ## Examples

      VeChain.Telemetry.detach("my-handler")
  """
  @spec detach(handler_id :: String.t() | atom()) ::
          :ok | {:error, :not_found}
  def detach(handler_id) do
    :telemetry.detach(handler_id)
  end

  # Private helpers

  defp event_matches?(pattern, event_name) do
    pattern_length = length(pattern)
    event_prefix = Enum.take(event_name, pattern_length)
    pattern == event_prefix
  end
end
