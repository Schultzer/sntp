defmodule SNTP.Timestamp do
  @moduledoc false

  alias SNTP.Socket
  import Bitwise

  defstruct [
    d: nil,
    errors: [],
    is_valid?: false,
    leap_indicator: nil,
    mode: nil,
    originate_timestamp: nil,
    pool: nil,
    precision: nil,
    receive_timestamp: nil,
    received_locally: nil,
    reference_host: nil,
    reference_id: nil,
    reference_timestamp: nil,
    root_delay: nil,
    root_dispersion: nil,
    sent_locally: nil,
    stratum: nil,
    t: nil,
    transmit_timestamp: nil,
    version: nil
  ]

  @type t :: %__MODULE__{
    d: number(),
    is_valid?: boolean(),
    leap_indicator: number(),
    mode: binary(),
    originate_timestamp: number(),
    pool: number(),
    precision: number(),
    receive_timestamp: number(),
    received_locally: number(),
    reference_id: binary() | {pos_integer(), pos_integer(), pos_integer(), pos_integer()},
    reference_timestamp: number(),
    root_delay: number(),
    sent_locally: number(),
    stratum: binary(),
    t: number(),
    transmit_timestamp: number(),
    version: number()
  }

  @doc false
  @spec parse(Socket.t()) :: t()
  def parse(%Socket{message: message, resolve_reference: resolve_reference}) do
    _parse(message, resolve_reference)
  end
  def _parse(%{data: data, sent_at: sent_at, received_at: received_at}, resolve_reference) do
    _parse(data, sent_at, received_at, resolve_reference)
  end
  def _parse(<<li::2, vn::integer-size(3), mode::3, stratum::unsigned-integer-size(8), poll::unsigned-integer-size(8),
              precision::signed-integer-size(8), root_del::32, root_disp::32, ref_id::bitstring-size(32),
              ref::64, t1::64, t2::64, t3::64>>, sent_at, received_at, resolve_reference) do

    stratum = set_stratum(stratum)

    opts = [leap_indicator:      set_leap_indicator(li),
            version:             vn,
            mode:                set_mode(mode),
            stratum:             stratum,
            pool:                Kernel.round(bsl(1, poll)) * 1000,         # milliseconds,
            precision:           :math.pow(2, precision)    * 1000,         # milliseconds,
            root_delay:          root_del                   * 1000,         # milliseconds,
            root_dispersion:     (root_disp / bsl(1, 16))   * 1000,         # milliseconds,
            reference_id:        set_reference_id(stratum, <<ref_id::bitstring-size(32)>>),
            reference_timestamp: to_msec(<<ref::64>>),
            originate_timestamp: to_msec(<<t1::64>>),
            receive_timestamp:   to_msec(<<t2::64>>),
            transmit_timestamp:  to_msec(<<t3::64>>),
            sent_locally:        sent_at,
            received_locally:    received_at]

    @struct
    |> Kernel.struct(opts)
    |> validate()
    |> calc_roundtrip()
    |> resolve_reference(resolve_reference)
  end

  defp validate(%__MODULE__{originate_timestamp: t1, sent_locally: sent} = timestamp) when t1 != sent do
    add_error(timestamp, :originate_timestamp, "Wrong originate timestamp")
  end
  defp validate(%__MODULE__{errors: [], mode: "server", version: 4, stratum: stratum} = timestamp) when stratum != "reserved" do
    %{timestamp | is_valid?: true}
  end
  defp validate(timestamp), do: add_error(timestamp, :response, "Invalid server response")

  @doc !"""
  Timestamp Name          ID   When Generated
  ------------------------------------------------------------
  Originate Timestamp     T1   time request sent by client
  Receive Timestamp       T2   time request received by server
  Transmit Timestamp      T3   time reply sent by server
  Destination Timestamp   T4   time reply received by client

  The roundtrip delay d and system clock offset t are defined as:

  d = (T4 - T1) - (T3 - T2)     t = ((T2 - T1) + (T3 - T4)) / 2
  """
  defp calc_roundtrip(%__MODULE__{errors: [], originate_timestamp: t1, receive_timestamp: t2, transmit_timestamp: t3, received_locally: t4} = message) do
    d = (t4 - t1) - (t3 - t2)
    t = ((t2 - t1) + (t3 - t4)) / 2
    %{message | d: d, t: t}
  end
  defp calc_roundtrip(timestamp), do: timestamp

  defp resolve_reference(%__MODULE__{stratum: "secondary", reference_id: ref_id} = timestamp, true) do
    case :inet_res.gethostbyaddr(ref_id) do
      {:error, reason} -> add_error(timestamp, :resolve_ref, {reason, "Failed to resovle reference"})

      {:ok, host}      -> %{timestamp | reference_host: host}
    end
  end
  defp resolve_reference(timestamp, true), do: add_error(timestamp, :resolve_ref, {:stratum_not_secondary, "Failed to resovle reference"})
  defp resolve_reference(timestamp, false), do: timestamp

  defp set_leap_indicator(0), do: "no-warning"
  defp set_leap_indicator(1), do: "last-minute-61"
  defp set_leap_indicator(2), do: "last-minute-59"
  defp set_leap_indicator(3), do: "alarm"

  defp set_mode(1), do: "symmetric-active"
  defp set_mode(2), do: "symmetric-passive"
  defp set_mode(3), do: "client"
  defp set_mode(4), do: "server"
  defp set_mode(5), do: "broadcast"
  defp set_mode(n) when n in [0, 6, 7], do: "reserved"

  defp set_stratum(0),  do: "death"
  defp set_stratum(1),  do: "primary"
  defp set_stratum(n) when n in 2..15, do: "secondary"
  defp set_stratum(_),  do: "reserved"

  defp set_reference_id("reserved", _), do: ""
  defp set_reference_id("secondary", <<r1, r2, r3, r4>>), do: {r1, r2, r3, r4}
  defp set_reference_id(s, ref_id) when s in ["death", "primary"], do: ref_id

  @doc !"""
  There is serevels ways the operation migth be optimazed
  instead of calling `:math.pow(2, 32)` we could do `bsl(1, 32)` witch is faster or just throw in `294967296` but will all machine produce `294967296`?

  Thease a special const beacuse around 2036 there will be a integer overflow in the NTP Timestamp.
  The RFC cover this.
  2085978496 == 7-Feb-2036 @ 06:28:16 UTC
  2208988800 == 1-Jan-1900 @ 01:00:00 UTC
  """
  defp to_msec(<<seconds::32, fraction::32>>) do
    epoch = case band(seconds, 16) do 0 -> 2085978496; _ -> 2208988800 end
    ((reduce(<<seconds::32>>) - epoch + (reduce(<<fraction::32>>) / :math.pow(2, 32))) * 1000)
  end

  defp reduce(number) do
    Enum.reduce(:erlang.binary_to_list(number), 0, fn n, number -> (number * 256 + n) end)
  end

  defp add_error(%__MODULE__{errors: errors} = timestamp, error, reason) do
    case Keyword.has_key?(errors, error) do
      false -> Kernel.struct(timestamp, errors: [{error, reason} | errors])

      true  -> timestamp
    end
  end
end
