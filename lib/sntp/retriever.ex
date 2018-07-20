defmodule SNTP.Retriever do
  @moduledoc false

  alias SNTP.{Socket, Timestamp}
  require Logger
  use GenServer

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def stop(pid) do
    GenServer.cast(pid, :stop)
    GenServer.stop(pid)
  end

  def init(config) do
    :erlang.process_flag(:trap_exit, true)
    config = Enum.reduce(config, %{auto_start: true, retreive_every: 86400000}, fn {k, v}, acc -> Map.update(acc, k, v, &(if &1 == v, do: &1, else: v)) end)
    if config[:auto_start], do: schedule_retreive(5000)
    {:ok, %{socket: Socket.new(config), retreive_every: config[:retreive_every] || 86400000}}
  end

  def handle_cast(:stop, %{socket: socket}) do
    Socket.close(socket)
    {:noreply, %{}}
  end

  def handle_info(:retreive, %{socket: socket, retreive_every: retreive_every}) do
    socket = Socket.send(socket)
    timestamp = Timestamp.parse(socket)
    store_timestamp(timestamp)
    {:noreply, %{socket: socket, retreive_every: retreive_every}}
  end

  defp schedule_retreive(wait) do
    Process.send_after(self(), :retreive, wait)
  end

  defp store_timestamp(%Timestamp{is_valid?: true, received_locally: time} = timestamp) do
    case :ets.info(:sntp) do
      [] ->
        :ets.insert(:sntp, lastest: timestamp)

      :undefined ->
        :ets.new(:sntp, [:named_table, :public, read_concurrency: true])
        :ets.insert(:sntp, lastest: timestamp)
    end
    Logger.info "Timestamp retrieved at #{time}. Next retrieval in #{Application.get_env(:sntp, :retreive_every, 86400000)}"
  end
  defp store_timestamp(%Timestamp{is_valid?: false, received_locally: time}) do
    Logger.warn "Timestamp retrieved at #{time} is invalid. Next retrieval in #{Application.get_env(:sntp, :retreive_every, 86400000)}"
  end
end
