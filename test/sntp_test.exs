defmodule SNTPTest do
  use ExUnit.Case
  # doctest SNTP

  import SNTP

  test "returns consistent result over multiple tries" do
    time1 = SNTP.time!()
    t1 = time1.t
    time2 = SNTP.time!()
    t2 = time2.t

    assert Kernel.abs(t1 - t2) < 200
  end

  test "resolves reference IP" do
    time = SNTP.time!(%{host: 'pool.ntp.org', port: 123, resolve_reference: true })

    assert Map.has_key?(time, :reference_host) == true
  end

  test "times out on no response" do
    time = SNTP.time(%{host: 'ntp.exnet.com', port: 123, resolve_reference: true, timeout: 100 })
    assert time == {:error, "Timeout"}
  end

  test "times out on invalid host" do
    time = SNTP.time(%{host: 'time.blackhole.nowhere', port: 123, resolve_reference: false, timeout: 100})
    assert time == {:error, "Timeout"}
  end

end
