defmodule SNTP.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one, name: SNTP.Supervisor)
  end

  def children() do
    case Application.get_env(:sntp, :auto_start, false) do
      true  -> [%{id: SNTP.Retriever, start: {SNTP.Retriever, :start_link, [Application.get_all_env(:sntp)]}}]

      false -> []
     end
  end
end
