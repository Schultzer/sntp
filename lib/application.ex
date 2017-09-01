defmodule SNTP.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(ConCache, [[ttl_check: :timer.seconds(1), ttl: :timer.hours(24)], [name: :cache]],[ id: :cache, modules: [ConCache]])
    ]

    opts = [strategy: :one_for_one, name: SNTP.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
