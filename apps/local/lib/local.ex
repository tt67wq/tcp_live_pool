defmodule Local do
  @moduledoc """
  Documentation for Local.
  """

  def start(_type, _args) do
    children = [
      Local.TcpPool
    ]

    opts = [strategy: :one_for_one, name: Local.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
