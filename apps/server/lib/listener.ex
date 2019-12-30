defmodule Server.Listener do
  @moduledoc false

  use GenServer
  require Logger

  @ports Application.get_env(:server, :ports, [8080])

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def send_data(client, data), do: Socket.Stream.send(client, <<2::size(8), 0::size(8)>> <> data)

  def init(_args) do
    @ports
    |> Enum.map(fn port -> Socket.TCP.listen!(port) end)
    |> Enum.each(fn listener -> Process.send_after(self(), {:loop_accept, listener}, 1000) end)

    {:ok, %{}}
  end

  def handle_info({:loop_accept, listener}, state) do
    Logger.info("listening...")
    {:ok, client} = Socket.TCP.accept(listener)

    Logger.info("new client established")
    # serve client
    Task.Supervisor.start_child(Server.TaskSupervisor, fn -> serve(client) end)

    Process.send(self(), {:loop_accept, listener}, [])
    {:noreply, state}
  end

  defp serve(client) do
    case recv(client) do
      {:ok, data} when data != nil ->
        process(client, data)
        serve(client)

      reason ->
        Logger.warn("client closed for #{inspect(reason)}")
        Socket.Stream.close(client)
    end
  end

  defp recv(client) do
    case Socket.Stream.recv(client) do
      {:ok, <<1::size(8), _sid::size(8), _cookie::binary>> = data} ->
        Socket.Stream.send(client, data)
        recv(client)

      {:ok, <<2::size(8), _sid::size(8), data::binary>>} ->
        {:ok, <<data::binary>>}

      _ ->
        {:ok, nil}
    end
  end

  # real data
  defp process(client, data) do
    send_data(client, data <> " too!")
  end
end
