defmodule SNTP.Socket do
  @moduledoc false

  alias SNTP.NTPMessage

  defstruct [
    errors: [],
    host: 'pool.ntp.org',
    host_port: 123,
    message: %NTPMessage{},
    port: nil,
    resolve_reference: false,
    timeout: :infinity
  ]

  @type t :: %__MODULE__{
    errors: [],
    host: [],
    host_port: 0..65535,
    message: NTPMessage.t(),
    port: nil | port(),
    resolve_reference: boolean(),
    timeout: :infinity | pos_integer()
  }

  @doc """
  Initialize a New `SNTP.Socket.t()`

  ## Examples

      iex> SNTP.Socket.new()
      %SNTP.Socket{}
  """
  @spec new(Enumerable.t()) :: t()
  def new(opts \\ []) do
    opts = validate_opts(opts)
    __MODULE__
    |> Kernel.struct(opts)
    |> open()
  end

  @doc """
  Send a NTP message on the `SNTP.Socket.t()`

  ## Examples

      iex> socket = SNTP.Socket.new()
      iex> SNTP.Socket.send(socket).message.data !== nil
      true
  """
  @spec send(t()) :: t()
  def send(%__MODULE__{port: nil} = socket), do: add_error(socket, :no_port_open, "Unable to send NTP message")
  def send(%__MODULE__{message: message, port: port, host: host, host_port: host_port, timeout: timeout} = socket) do
    ts = :erlang.system_time(1000)
    t3s = div(ts, 1000) + 2208988800
    t3f = Kernel.round((Integer.mod(ts, 1000) / 1000) * 4294967296)

    case :gen_udp.send(port, host, host_port, <<0::2, 4::3, 3::3, 0::8-unit(3), 0::32-unit(3), 0::64-unit(3), t3s::32, t3f::32>>) do
      {:error, reason} -> add_error(socket, :udp_send, reason)

      :ok              ->
        receive do
          {:udp, ^port, ip, ^host_port, data} ->
            message = Kernel.struct(message, data: data, ip: ip, sent_at: ts, received_at: :erlang.system_time(1000))
            Kernel.struct(socket, message: message)
        after
          timeout -> add_error(socket, :timeout, "Server Timeout after #{inspect timeout}")
        end
    end
  end

  @doc """
  Closes a `SNTP.Socket.t()`

  ## Examples

      iex> open_socket = SNTP.Socket.open(%SNTP.Socket{})
      iex> SNTP.Socket.close(open_socket).port
      nil
  """
  @spec close(t()) :: t()
  def close(%__MODULE__{port: nil} = socket), do: socket
  def close(%__MODULE__{port: port} = socket) when is_port(port) do
    :gen_udp.close(port)
    %{socket | port: nil}
  end

  @doc """
  Opens a `SNTP.Socket.t()`

  ## Examples

      iex> socket = %SNTP.Socket{}
      iex> SNTP.Socket.open(socket).port !== nil
      true
  """
  @spec open(t()) :: t()
  def open(%__MODULE__{} = socket) do
    case :gen_udp.open(0, [:binary])do
      {:error, reason} -> add_error(socket, :upd_open, reason)

      {:ok, port}      -> remove_error(%{socket | port: port}, :no_port_open)
    end
  end

  defp add_error(%__MODULE__{errors: errors} = socket, error, msg) do
    case Keyword.has_key?(errors, error) do
      false -> %{socket | errors: [{error, msg} | errors]}

      true  -> socket
    end
  end

  defp remove_error(%__MODULE__{errors: errors} = socket, error) do
    case Keyword.has_key?(errors, error) do
      false -> %{socket | errors: Keyword.delete(errors, error)}

      true  -> socket
    end
  end


  @keys ~w(host host_port resolve_reference timeout)a ++
        ~w(host host_port resolve_reference timeout)c ++
        ~w(host host_port resolve_reference timeout)s
  defp validate_opts(opts) do
    opts
    |> Enum.reduce(%{}, fn
         {k, v}, acc when is_atom(k)   and k in @keys -> Map.update(acc, k, v, &(&1 = v))
         {k, v}, acc when is_binary(k) and k in @keys -> Map.update(acc, String.to_atom(k), v, &(&1 = v))
         {k, v}, acc when is_list(k)   and k in @keys -> Map.update(acc, List.to_atom(k), v, &(&1 = v))
         _, acc -> acc
       end)
    |> Enum.reduce(%{}, fn
         {:host, v}, acc              when is_binary(v) or is_list(v)     -> Map.put(acc, :host, '#{v}')
         {:host, v}, acc              when not is_binary(v) or is_list(v) -> Map.put(acc, :host, 'pool.ntp.org')
         {:host_port, v}, acc         when v not in 0..65535              -> Map.put(acc, :host_port, 123)
         {:resolve_reference, v}, acc when not is_boolean(v)              -> Map.put(acc, :resolve_reference, false)
         {k, v}, acc                                                      -> Map.put(acc, k, v)
       end)
  end
end
