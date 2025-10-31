defmodule VeChain.Error do
  @moduledoc """
  Exception modules for VeChain SDK errors.

  Provides specific error types for different failure scenarios:
  - Address validation errors
  - Private key errors
  - Gas estimation errors
  - Transaction execution errors
  - Network communication errors
  - Encoding/decoding errors
  - Signature errors
  - Contract interaction errors
  """

  defmodule InvalidAddress do
    @moduledoc """
    Exception raised when an invalid address format is provided.

    An address must be a 40-character hex string (with optional 0x prefix),
    representing 20 bytes.
    """
    defexception [:message]

    @impl true
    def exception(opts) do
      address = Keyword.get(opts, :address)
      message = Keyword.get(opts, :message, build_message(address))
      %__MODULE__{message: message}
    end

    defp build_message(nil), do: "Invalid address format"
    defp build_message(address), do: "Invalid address format: #{inspect(address)}"
  end

  defmodule InvalidPrivateKey do
    @moduledoc """
    Exception raised when an invalid private key is provided.

    A private key must be 32 bytes (64 hex characters with optional 0x prefix).
    """
    defexception [:message]

    @impl true
    def exception(opts) do
      message = Keyword.get(opts, :message, "Invalid private key format")
      %__MODULE__{message: message}
    end
  end

  defmodule InsufficientGas do
    @moduledoc """
    Exception raised when the provided gas is insufficient for the transaction.

    This can occur during gas estimation or when explicitly setting gas too low.
    """
    defexception [:message, :required, :provided]

    @impl true
    def exception(opts) do
      required = Keyword.get(opts, :required)
      provided = Keyword.get(opts, :provided)
      message = Keyword.get(opts, :message, build_message(required, provided))

      %__MODULE__{
        message: message,
        required: required,
        provided: provided
      }
    end

    defp build_message(nil, nil), do: "Insufficient gas for transaction"

    defp build_message(required, provided) do
      "Insufficient gas: required #{required}, provided #{provided}"
    end
  end

  defmodule TransactionReverted do
    @moduledoc """
    Exception raised when a transaction is reverted by the blockchain.

    Contains the revert reason if available.
    """
    defexception [:message, :transaction_id, :revert_reason]

    @impl true
    def exception(opts) do
      transaction_id = Keyword.get(opts, :transaction_id)
      revert_reason = Keyword.get(opts, :revert_reason)
      message = Keyword.get(opts, :message, build_message(transaction_id, revert_reason))

      %__MODULE__{
        message: message,
        transaction_id: transaction_id,
        revert_reason: revert_reason
      }
    end

    defp build_message(nil, nil), do: "Transaction reverted"
    defp build_message(tx_id, nil), do: "Transaction #{tx_id} reverted"

    defp build_message(tx_id, reason) when is_binary(reason) do
      "Transaction #{tx_id} reverted: #{reason}"
    end

    defp build_message(nil, reason) when is_binary(reason) do
      "Transaction reverted: #{reason}"
    end
  end

  defmodule NetworkError do
    @moduledoc """
    Exception raised when a network communication error occurs.

    This includes connection failures, timeouts, and HTTP errors
    when communicating with Thor nodes.
    """
    defexception [:message, :status_code, :reason]

    @impl true
    def exception(opts) do
      status_code = Keyword.get(opts, :status_code)
      reason = Keyword.get(opts, :reason)
      message = Keyword.get(opts, :message, build_message(status_code, reason))

      %__MODULE__{
        message: message,
        status_code: status_code,
        reason: reason
      }
    end

    defp build_message(nil, nil), do: "Network error"
    defp build_message(status, nil), do: "Network error: HTTP #{status}"
    defp build_message(nil, reason), do: "Network error: #{inspect(reason)}"
    defp build_message(status, reason), do: "Network error: HTTP #{status} - #{inspect(reason)}"
  end

  defmodule EncodingError do
    @moduledoc """
    Exception raised when encoding or decoding data fails.

    This includes RLP encoding errors, ABI encoding errors,
    and hex string parsing errors.
    """
    defexception [:message, :data, :reason]

    @impl true
    def exception(opts) do
      data = Keyword.get(opts, :data)
      reason = Keyword.get(opts, :reason)
      message = Keyword.get(opts, :message, build_message(data, reason))

      %__MODULE__{
        message: message,
        data: data,
        reason: reason
      }
    end

    defp build_message(nil, nil), do: "Encoding/decoding error"
    defp build_message(nil, reason), do: "Encoding/decoding error: #{inspect(reason)}"

    defp build_message(data, nil) do
      "Encoding/decoding error for data: #{inspect(data)}"
    end

    defp build_message(data, reason) do
      "Encoding/decoding error for data #{inspect(data)}: #{inspect(reason)}"
    end
  end

  defmodule SignatureError do
    @moduledoc """
    Exception raised when signature operations fail.

    This includes signing failures, signature verification failures,
    and public key recovery failures.
    """
    defexception [:message, :reason]

    @impl true
    def exception(opts) do
      reason = Keyword.get(opts, :reason)
      message = Keyword.get(opts, :message, build_message(reason))

      %__MODULE__{
        message: message,
        reason: reason
      }
    end

    defp build_message(nil), do: "Signature operation failed"
    defp build_message(reason), do: "Signature operation failed: #{inspect(reason)}"
  end

  defmodule TransactionError do
    @moduledoc """
    Generic exception for transaction-related errors.

    Use more specific exceptions when possible (e.g., TransactionReverted,
    InsufficientGas), but fall back to this for general transaction failures.
    """
    defexception [:message, :transaction, :reason]

    @impl true
    def exception(opts) do
      transaction = Keyword.get(opts, :transaction)
      reason = Keyword.get(opts, :reason)
      message = Keyword.get(opts, :message, build_message(reason))

      %__MODULE__{
        message: message,
        transaction: transaction,
        reason: reason
      }
    end

    defp build_message(nil), do: "Transaction error"
    defp build_message(reason), do: "Transaction error: #{inspect(reason)}"
  end

  defmodule ContractError do
    @moduledoc """
    Exception raised when contract interaction fails.

    This includes contract call failures, deployment failures,
    and ABI encoding/decoding errors.
    """
    defexception [:message, :contract_address, :function, :reason]

    @impl true
    def exception(opts) do
      contract_address = Keyword.get(opts, :contract_address)
      function = Keyword.get(opts, :function)
      reason = Keyword.get(opts, :reason)
      message = Keyword.get(opts, :message, build_message(contract_address, function, reason))

      %__MODULE__{
        message: message,
        contract_address: contract_address,
        function: function,
        reason: reason
      }
    end

    defp build_message(nil, nil, nil), do: "Contract interaction error"

    defp build_message(address, nil, nil) when is_binary(address) do
      "Contract interaction error at #{address}"
    end

    defp build_message(address, function, nil)
         when is_binary(address) and is_binary(function) do
      "Contract interaction error calling #{function} at #{address}"
    end

    defp build_message(address, function, reason)
         when is_binary(address) and is_binary(function) do
      "Contract interaction error calling #{function} at #{address}: #{inspect(reason)}"
    end

    defp build_message(_, _, reason) when reason != nil do
      "Contract interaction error: #{inspect(reason)}"
    end

    defp build_message(_, _, _), do: "Contract interaction error"
  end

  @doc """
  Convert an error tuple to an exception.

  Useful for converting `{:error, reason}` tuples into exceptions
  that can be raised.

  ## Examples

      iex> VeChain.Error.to_exception({:error, :invalid_address})
      %VeChain.Error.TransactionError{message: "Transaction error: :invalid_address"}

      iex> VeChain.Error.to_exception({:error, %VeChain.Error.InvalidAddress{}})
      %VeChain.Error.InvalidAddress{message: "Invalid address format"}
  """
  @spec to_exception({:error, term()}) :: Exception.t()
  def to_exception({:error, %_{} = exception}) when is_exception(exception) do
    exception
  end

  def to_exception({:error, reason}) do
    %TransactionError{message: "Transaction error: #{inspect(reason)}", reason: reason}
  end

  @doc """
  Wrap a value in an ok/error tuple.

  Returns `{:ok, value}` if value is not an error,
  or `{:error, reason}` if it's an exception.

  ## Examples

      iex> VeChain.Error.wrap(42)
      {:ok, 42}

      iex> VeChain.Error.wrap(%VeChain.Error.InvalidAddress{message: "bad"})
      {:error, %VeChain.Error.InvalidAddress{message: "bad"}}
  """
  @spec wrap(term()) :: {:ok, term()} | {:error, Exception.t()}
  def wrap(%_{} = value) when is_exception(value) do
    {:error, value}
  end

  def wrap(value) do
    {:ok, value}
  end
end
