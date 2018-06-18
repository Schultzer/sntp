defmodule SNTP do
  @moduledoc """
  SNTP v4 client [RFC4330](https://tools.ietf.org/html/rfc4330) for Elixir
  """
  alias SNTP.{Retriever, RetrieverError, Socket, Timestamp}

  @doc """
  Returns the system time in milliseconds.
  If the `SNTP.Retriever` is running then it will return the adjusted system time.

  ## Examples

      iex> SNTP.now()
      System.system_time(1000)

  """
  @spec now() :: pos_integer()
  def now() do
    case :ets.info(:sntp) do
      :undefined -> System.system_time(1000)

      []         ->
        [lastest: %{t: offset, is_valid?: is_valid?}] = :ets.lookup(:sntp, :lastest)
        case is_valid? do
          false -> System.system_time(1000)

          true  -> offset + System.system_time(1000)
        end
    end
  end


  @doc """
  Returns the latest retrieved offset from the `SNTP.Retriever`

  ## Examples

      iex> SNTP.offset()
      {:ok, 12}

      iex> SNTP.offset()
      {:error, {SNTP.RetrieverError, "SNTP Retriever is not started"}}
  """
  @spec offset() :: {:ok, number()} | {:error, {Exception.t(), binary()}}
  def offset() do
    case :ets.info(:sntp) do
      :undefined -> {:error, {RetrieverError, "SNTP Retriever is not started"}}

      []         ->
        [lastest: %{t: offset}] = :ets.lookup(:sntp, :lastest)
        {:ok, offset}
    end
  end

  @doc """
  Starts the `SNTP.Retriever`

  * `options` are an `Enumerable.t()` with these keys:
    * `auto_start` is a `boolean()` defaults to `true`
    * `retreive_every` is a `non_neg_integer()` defaults to `86400000` every 24 hour
    * `host` is `binary() | charlist()` defualts to `'pool.ntp.org'`
    * `port` is an `non_neg_integer()` between `0..65535` defualts to `123`
    * `timeout` is an `non_neg_integer()` defualts to `:infinity`
    * `resolve_reference` is a `boolean()` defualts to `false`

  ## Examples

      iex> SNTP.start()
      #PID<0.000.0>
  """
  @spec start(Enumerable.t()) :: pid()
  defdelegate start(config), to: Retriever, as: :start_link

  @doc """
  Stops the `SNTP.Retriever`

  ## Examples

      iex> SNTP.stop()
      :ok
  """
  @spec stop(pid()) :: :ok
  defdelegate stop(pid \\ GenServer.whereis(Retriever)), to: Retriever

  @doc """
  Sends a new NTP request on an `SNTP.Socket` and gracefully closes the socket.
  Returns `{:ok, %SNTP.Timestamp{}}` or `{:error, reason}`

  * `options` an `Enumerable.t()` with these keys:
    * `host` is `binary() | charlist()` defualts to `'pool.ntp.org'`
    * `port` is an `non_neg_integer()` between `0..65535` defualts to `123`
    * `timeout` is an `non_neg_integer()` defualts to `:infinity`
    * `resolve_reference` is a `boolean()` defualts to `false`

  ## Examples

      iex> {:ok, timestamp} = SNTP.time()
      iex> timestamp.is_valid?
      true

      iex> SNTP.time(host: 'ntp.exnet.com', port: 123, timeout: 100))
      {:error, [timeout: "Server Timeout after 100"]}
  """
  @spec time(Enumerable.t()) :: {:ok, integer()} | {:error, term()}
  def time(options \\ []) do
    options
    |> Socket.new()
    |> Socket.send()
    |> Socket.close()
    |> parse()
  end

  defp parse(%Socket{errors: []} = socket) do
    socket
    |> Timestamp.parse()
    |> parse()
  end
  defp parse(%Socket{errors: errors}) do
    {:error, errors}
  end
  defp parse(timestamp) do
    case timestamp.is_valid? do
      false -> {:error, timestamp.errors}

      true  -> {:ok, timestamp}
    end
  end
end
