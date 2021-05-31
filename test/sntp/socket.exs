defmodule SNTP.SocketTest do
  use ExUnit.Case
  alias SNTP.Socket

  # doctest SNTP.Socket

  test "new/0" do
    assert %Socket{} = Socket.new
  end

  test "open/1" do
    assert %Socket{port: port} = Socket.open(%Socket{})
    assert is_port(port)
  end

  test "close/1" do
    socket = Socket.new
    assert %Socket{port: nil} = Socket.close(socket)
  end
end
