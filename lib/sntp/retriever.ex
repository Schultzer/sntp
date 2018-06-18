defmodule SNTP.Retriever do
  @moduledoc false

  alias SNTP.{Socket, Timestamp}
  use GenServer

  def start_link(config \\ []) do
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    pid
  end

  def stop(pid) do
    GenServer.cast(pid, :stop)
    GenServer.stop(pid)
  end

  def init(config) do
    config = Enum.reduce(config, %{auto_start: true, retreive_every: 86400000}, fn {k, v}, acc -> Map.update(acc, k, v, &(if &1 == v, do: &1, else: v)) end)
    if config[:auto_start], do: schedule_retreive(5000)
    {:ok, {Socket.new(config), config[:retreive_every] || 86400000}}
  end

  def handle_cast(:stop, {socket, _retreive_every}) do
    Socket.close(socket)
    {:noreply, {}}
  end

  def handle_info(:retreive, {socket, retreive_every}) do
    socket = Socket.send(socket)
    timestamp = Timestamp.parse(socket)
    store_timestamp(timestamp)
    {:noreply, {socket, retreive_every}}
  end

  defp schedule_retreive(wait) do
    Process.send_after(self(), :retreive, wait)
  end

  defp store_timestamp(%Timestamp{is_valid?: true} = timestamp) do
    case :ets.info(:sntp) do
      [] ->
        :ets.insert(:sntp, lastest: timestamp)

      :undefined ->
        :ets.new(:sntp, [:named_table, :public, read_concurrency: true])
        :ets.insert(:sntp, lastest: timestamp)
    end
  end
end
