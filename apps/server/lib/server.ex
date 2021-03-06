defmodule Server do
  @moduledoc """
  Documentation for Server.
  """

  def start(_type, _args) do
    children = [
      Server.Listener,
      {Task.Supervisor, name: Server.TaskSupervisor},
    ]

    opts = [strategy: :one_for_one, name: Server.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
