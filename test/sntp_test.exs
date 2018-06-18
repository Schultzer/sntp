defmodule SNTPTest do
  use ExUnit.Case

  test "returns consistent result over multiple tries" do
    {:ok, %{t: t1}} = SNTP.time()
    {:ok, %{t: t2}} = SNTP.time()
    assert Kernel.abs(t1 - t2) < 200
  end

  test "resolves reference IP" do
    {:ok, time} = SNTP.time(host: 'ntp.exnet.com', port: 123, timeout: :infinity, resolve_reference: true)
    refute is_nil(time.reference_host)
  end

  test "times out on no response" do
    {:error, errors} = SNTP.time(host: 'ntp.exnet.com', port: 123, timeout: 100)
    assert errors[:timeout] == "Server Timeout after 100"
  end

  test "invalid host" do
    {:error, errors} = SNTP.time(host: 'time.blackhole.nowhere', port: 123, timeout: 100)
    assert errors[:udp_send] == :nxdomain
  end
end
