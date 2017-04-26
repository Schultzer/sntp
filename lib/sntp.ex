defmodule SNTP do
  import Bitwise

  @options %{
    host: 'pool.ntp.org',
    port: 123,
    resolve_reference: false,
    timeout: :infinity
  }

  def time(options \\ @options) do
    sent = :erlang.system_time(1000)
    message = sent |> from_msec |> create_ntp_message

    ntp_message = udp_socket_open()
                  |> udp_socket_send(options, message)
                  |> udp_socket_receive(options)
                  |> udp_socket_close
                  |> validate_ntp_message
                  |> validate(sent)
                  |> resolve(options)

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

    t1 = ntp_message.originate_timestamp
    t2 = ntp_message.receive_timestamp
    t3 = ntp_message.transmit_timestamp
    t4 = ntp_message.received_locally

    ntp_message
    |> Map.put_new(:d, (t4 - t1) - (t3 - t2))
    |> Map.put_new(:t, ((t2 - t1) + (t3 - t4)) / 2)
  end

  def validate({:ok, message}, sent) do
    case message.originate_timestamp != sent do
      true  -> {:error, "Wrong originate timestamp"}
      false -> {:ok, message}
    end
  end
  def validate({:error, reason, _message}, _sent), do: reason

  def resolve({:ok, message}, options) do
    case message.stratum != "secondary" and options.resolve_reference != false do
      true -> message.reference_id |> get_host_by_addr(message)
      _    -> message

    end
  end
  def resolve({:error, reason}, _options), do: raise ArgumentError, reason

  def get_host_by_addr({:ok, host}, message) do
    message |> Map.put_new(:reference_host, host)
  end
  def get_host_by_addr({:error, reason}, _message), do: reason
  def get_host_by_addr(id, message) do
    :inet_res.gethostbyaddr(id) |> get_host_by_addr(message)
  end

  def udp_socket_open(), do: :gen_udp.open(0, [:binary]) |> udp_socket_open
  def udp_socket_open({:ok, socket}), do: socket
  def udp_socket_open({:error, resaon}), do: resaon

  def udp_socket_send(socket, options, message), do: :gen_udp.send(socket, options.host, options.port, message)

  def udp_socket_receive(socket, options) do
    receive do
      {_udp, socket, _ip, _port, message} -> {socket, message, :erlang.system_time(1000)}
    after
      options.timeout                     -> {socket, :error}
    end
  end

  def udp_socket_close({socket, message, received}) do
    socket |> :gen_udp.close
    message |> ntp_message(received)
  end
  def udp_socket_close({socket, :error}) do
    socket |> :gen_udp.close
    {:error, "Timeout"}
  end

  def create_ntp_message({t3s, t3f}) do
    <<0::2, 4::3, 3::3, 0::8-unit(3), 0::32-unit(3), 0::64-unit(3), t3s::32, t3f::32>>
  end

  def ntp_message(<<li::2, vn::3, mode::3, stratum::8, poll::8, precision::8,
                    root_del::32, root_disp::32, r1::8, r2::8, r3::8, r4::8,
                    refsec::32, reffrac::32, t1s::32, t1f::32, t2s::32, t2f::32, t3s::32, t3f::32>>, received) do

    leap_indicator      = set_leap_indicator(li)
    version             = vn
    mode                = set_mode(mode)
    stratum             = set_stratum(stratum)
    poll_interval       = Kernel.round(bsl(1, poll)) * 1000         # milliseconds
    precision           = :math.pow(2, precision)    * 1000         # milliseconds
    root_delay          = root_del                   * 1000         # milliseconds
    root_dispersion     = (root_disp / bsl(1, 16))   * 1000         # milliseconds
    reference_id        = set_reference_id(stratum, r1, r2, r3, r4)
    reference_timestamp = to_msec(refsec, reffrac)
    originate_timestamp = to_msec(t1s, t1f)
    receive_timestamp   = to_msec(t2s, t2f)
    transmit_timestamp  = to_msec(t3s, t3f)
    received_locally    = received

    %{
      leap_indicator:      leap_indicator,
      version:             version,
      mode:                mode,
      stratum:             stratum,
      pool:                poll_interval,
      precision:           precision,
      root_delay:          root_delay,
      root_dispersion:     root_dispersion,
      reference_id:        reference_id,
      reference_timestamp: reference_timestamp,
      originate_timestamp: originate_timestamp,
      receive_timestamp:   receive_timestamp,
      transmit_timestamp:  transmit_timestamp,
      received_locally:    received_locally
    }
  end

  def set_leap_indicator(0), do: "no-warning"
  def set_leap_indicator(1), do: "last-minute-61"
  def set_leap_indicator(2), do: "last-minute-59"
  def set_leap_indicator(3), do: "alarm"

  def set_mode(0), do: "reserved"
  def set_mode(1), do: "symmetric-active"
  def set_mode(2), do: "symmetric-passive"
  def set_mode(3), do: "client"
  def set_mode(4), do: "server"
  def set_mode(5), do: "broadcast"
  def set_mode(6), do: "reserved"
  def set_mode(7), do: "reserved"

  def set_stratum(0),  do: "death"
  def set_stratum(1),  do: "primary"
  def set_stratum(15), do: "secondary"
  def set_stratum(_),  do: "reserved"

  def set_reference_id("death", _r1, _r2, _r3, _r4), do: ""
  def set_reference_id("primary", r1, r2, r3, r4),   do: <<r1>> <> <<r2>> <> <<r3>> <> <<r4>> # r4 is zero padding
  def set_reference_id("secondary", r1, r2, r3, r4), do: '#{r1}.#{r2}.#{r3}.#{r4}'
  def set_reference_id(_, _r1, _r2, _r3, _r4),       do: ""

  def validate_ntp_message(message) do
    case message.version == 4 && message.stratum != "reserved" && message.mode == "server" do
      true -> {:ok, message}
      _    -> {:error, "Invalid server response", message}
    end
  end

  def to_msec({seconds, fractions}), do: to_msec(seconds, fractions)
  def to_msec(seconds, fractions) do
    case band(seconds, 16) do
      0 -> Kernel.round((seconds + 2085978496 + (fractions / bsl(1, 32))) * 1000)  # 7-Feb-2036 @ 06:28:16 UTC
      _ -> Kernel.round((seconds - 2208988800 + (fractions / bsl(1, 32))) * 1000)  # 1-Jan-1900 @ 01:00:00 UTC
    end
  end

  def from_msec(ts) do
    seconds   = Kernel.round(Float.floor(ts / 1000)) + 2208988800
    fractions = Kernel.round((Integer.mod(ts, 1000) / 1000) * bsl(1, 32))
    {seconds, fractions}
  end

  def offset() do
    now = :erlang.system_time(1000)
    clock_sync_refresh = 24 * 60 * 60 * 1000 # 24 hours

    time = time()
    %{offset: Kernel.round(time.t), expires: now + clock_sync_refresh}
  end

  def now(), do: :erlang.system_time(1000)
  def now(options) do
    now = :erlang.system_time(1000)
    case now >= options.expires do
      true  -> now
      false -> now + options.offset
    end
end
