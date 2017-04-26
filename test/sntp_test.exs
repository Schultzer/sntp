defmodule SNTPTest do
  use ExUnit.Case
  doctest ExSntp

  import SNTP

  test "returns consistent result over multiple tries" do
    time1 = SNTP.time()
    t1 = time1.t
    time2 = SNTP.time()
    t2 = time2.t

    assert Kernel.abs(t1 - t2) < 200
  end

  # test "resolves reference IP" do
  #   time = SNTP.time(%{ host: 'ntp.exnet.com', resolveReference: true })
  #
  #   assert time.reference_host === 'ntp.exnet.com'
  # end

  test "times out on no response" do
    time = SNTP.time(%{port: 124, timeout: 100})

    assert time == "Timeout"
  end
end
