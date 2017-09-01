defmodule SNTP do
  import Bitwise

  @options %{
    host: 'pool.ntp.org',
    port: 123,
    resolve_reference: false,
    timeout: :infinity
  }

  defp roundtrip({:ok, message}) do
    #  Timestamp Name          ID   When Generated
    #  ------------------------------------------------------------
    #  Originate Timestamp     T1   time request sent by client
    #  Receive Timestamp       T2   time request received by server
    #  Transmit Timestamp      T3   time reply sent by server
    #  Destination Timestamp   T4   time reply received by client
    #
    #  The roundtrip delay d and system clock offset t are defined as:
    #
    #  d = (T4 - T1) - (T3 - T2)     t = ((T2 - T1) + (T3 - T4)) / 2

    t1 = message.originate_timestamp
    t2 = message.receive_timestamp
    t3 = message.transmit_timestamp
    t4 = message.received_locally

    {:ok, message |> Map.put_new(:d, (t4 - t1) - (t3 - t2)) |> Map.put_new(:t, ((t2 - t1) + (t3 - t4)) / 2)}
  end
  defp roundtrip({:error, reason}), do: {:error, reason}


  defp validate({:error, reason}), do: {:error, reason}
  defp validate({:ok, message}) do
    case message.originate_timestamp != message.sent_locally do
      true  -> {:error, "Wrong originate timestamp"}
      false -> {:ok, message}
    end
  end
  defp validate({:error, reason, _message}), do: {:error, reason}

  defp resolve({:ok, message}, options) do
    case message.stratum != "secondary" and options.resolve_reference != false do
      true -> message.reference_id |> get_host_by_addr(message)
      _    -> {:ok, message}

    end
  end
  defp resolve({:error, reason}, _options), do: {:error, reason}

  defp get_host_by_addr({:ok, host}, message) do
    message |> Map.put_new(:reference_host, host)
  end
  defp get_host_by_addr({:error, reason}, _message), do: reason
  defp get_host_by_addr(id, message) do
    :inet_res.gethostbyaddr(id) |> get_host_by_addr(message)
  end

  defp udp_socket_open(), do: :gen_udp.open(0, [:binary]) |> udp_socket_open
  defp udp_socket_open({:ok, socket}), do: {:ok, socket}
  defp udp_socket_open({:error, reason}), do: {:error, reason}

  defp udp_socket_send({:ok, socket}, options) do
    sent = :erlang.system_time(1000)
    message = sent |> from_msec |> create_ntp_message

    {:gen_udp.send(socket, options.host, options.port, message), sent}
  end
  defp udp_socket_send({:error, reason}, _options), do: {:error, reason}

  defp udp_socket_receive({socket, sent}, options) do
    receive do
      {_udp, socket, _ip, _port, message} -> {socket, message, sent, :erlang.system_time(1000)}
    after
      options.timeout                     -> {:error, socket}
    end
  end
  defp udp_socket_receive({:error, reason}, _options), do: {:error, reason}

  defp udp_socket_close({socket, message, sent, received}) do
    :gen_udp.close(socket)
    ntp_message(message, sent, received)
  end
  defp udp_socket_close({:error, socket}) do
    # socket |> :gen_udp.close
    {:error, "Timeout"}
  end

  defp create_ntp_message({t3s, t3f}) do
    <<0::2, 4::3, 3::3, 0::8-unit(3), 0::32-unit(3), 0::64-unit(3), t3s::32, t3f::32>>
  end

  defp ntp_message(<<li::2, vn::3, mode::3, stratum::8, poll::8, precision::8,
                    root_del::32, root_disp::32, r1::8, r2::8, r3::8, r4::8,
                    refsec::32, reffrac::32, t1s::32, t1f::32, t2s::32, t2f::32, t3s::32, t3f::32>>, sent, received) do
    %{
      leap_indicator:      set_leap_indicator(li),
      version:             vn,
      mode:                set_mode(mode),
      stratum:             set_stratum(stratum),
      pool:                Kernel.round(bsl(1, poll)) * 1000,         # milliseconds,
      precision:           :math.pow(2, precision)    * 1000,         # milliseconds,
      root_delay:          root_del                   * 1000,         # milliseconds,
      root_dispersion:     (root_disp / bsl(1, 16))   * 1000,         # milliseconds,
      reference_id:        set_reference_id(stratum, r1, r2, r3, r4),
      reference_timestamp: to_msec(refsec, reffrac),
      originate_timestamp: to_msec(t1s, t1f),
      receive_timestamp:   to_msec(t2s, t2f),
      transmit_timestamp:  to_msec(t3s, t3f),
      sent_locally:        sent,
      received_locally:    received,
      is_valid:            false
    }
  end

  defp set_leap_indicator(0), do: "no-warning"
  defp set_leap_indicator(1), do: "last-minute-61"
  defp set_leap_indicator(2), do: "last-minute-59"
  defp set_leap_indicator(3), do: "alarm"

  defp set_mode(0), do: "reserved"
  defp set_mode(1), do: "symmetric-active"
  defp set_mode(2), do: "symmetric-passive"
  defp set_mode(3), do: "client"
  defp set_mode(4), do: "server"
  defp set_mode(5), do: "broadcast"
  defp set_mode(6), do: "reserved"
  defp set_mode(7), do: "reserved"

  defp set_stratum(0),  do: "death"
  defp set_stratum(1),  do: "primary"
  defp set_stratum(15), do: "secondary"
  defp set_stratum(_),  do: "reserved"

  defp set_reference_id("death", _r1, _r2, _r3, _r4), do: ""
  defp set_reference_id("primary", r1, r2, r3, r4),   do: <<r1>> <> <<r2>> <> <<r3>> <> <<r4>> # r4 is zero padding
  defp set_reference_id("secondary", r1, r2, r3, r4), do: '#{r1}.#{r2}.#{r3}.#{r4}'
  defp set_reference_id(_, _r1, _r2, _r3, _r4),       do: ""

  defp validate_ntp_message({:error, reason}), do: {:error, reason}
  defp validate_ntp_message(message) do
    case message.version == 4 && message.stratum != "reserved" && message.mode == "server" do
      true -> {:ok, Map.put(message, :is_valid, true)}
      _    -> {:error, "Invalid server response", message}
    end
  end

  defp to_msec({seconds, fractions}), do: to_msec(seconds, fractions)
  defp to_msec(seconds, fractions) do
    case band(seconds, 16) do
      0 -> Kernel.round((seconds + 2085978496 + (fractions / bsl(1, 32))) * 1000)  # 7-Feb-2036 @ 06:28:16 UTC
      _ -> Kernel.round((seconds - 2208988800 + (fractions / bsl(1, 32))) * 1000)  # 1-Jan-1900 @ 01:00:00 UTC
    end
  end

  defp from_msec(ts) do
    seconds   = Kernel.round(Float.floor(ts / 1000)) + 2208988800
    fractions = Kernel.round((Integer.mod(ts, 1000) / 1000) * bsl(1, 32))
    {seconds, fractions}
  end

  @moduledoc """
  Documentation for SNTP.
  """

  @doc """
  returns {:ok, timestamp} or {:error, reason}


  ## Examples

      iex> case SNTP.time() do {:ok, timestamp} -> :ok; {:error, reason} -> :error end
      (:ok || :error)

  """
  def time(options \\ @options) do
    udp_socket_open()
    |> udp_socket_send(options)
    |> udp_socket_receive(options)
    |> udp_socket_close
    |> validate_ntp_message
    |> validate
    |> resolve(options)
    |> roundtrip
  end
  @doc """
  returns timestamp or an error message


  ## Examples

      iex> case Kernel.is_map(SNTP.time!()) do true -> :ok; false -> :error end
      (:ok || :error)

  """
  def time!(options \\ @options) do
    {_status, message} = time(options)
    message
  end
  # @doc """
  # A convenience method there returns the offset and when it expires
  #
  # Note: offset are cached for 24 hours
  #
  # ## Examples
  #
  #     iex> SNTP.offset()
  #     %{expires: expires, offset: offset}
  #
  # """
  def offset(options \\ @options) do
    ConCache.get_or_store(:cache, "#{options.host}/#{options.port}/offset", fn ->
      now = :erlang.system_time(1000)
      clock_sync_refresh = 24 * 60 * 60 * 1000 # 24 hours
      expire = now + clock_sync_refresh
      case time(options) do
        {:ok, message}    -> offset(message, expire)
        {:error, reason}  -> offset()
      end
    end)
  end
  defp offset(time, expire), do: %{offset: Kernel.round(time.t), expires: expire}
  @doc """
  A convenience method there returns the system time

  ## Examples

      iex> SNTP.now() <= System.system_time(1000)
      (true || false)

  """
  def now() do
    case offset do
      {:error, _message} -> now()
      %{offset: offset, expires: expires} -> now(:erlang.system_time(1000), %{offset: offset, expires: expires})
    end
  end
  defp now(now, %{offset: offset, expires: expires}) do
    case now >= expires do
      false -> now + offset
      true  -> now
    end
  end
end
