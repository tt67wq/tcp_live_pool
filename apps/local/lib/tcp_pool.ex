defmodule Local.TcpPool do
  @moduledoc """
  tcp连接池
  """

  use GenServer
  require Logger

  @remote Application.get_env(:local, :remote_ip, "127.0.0.1")
  @ports Application.get_env(:local, :ports, [8080])
  @table_name :tcp_pool
  @pingpong_ttl 10_000

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def send_data(data) do
    GenServer.cast(__MODULE__, {:send, data})
  end

  defp get_port(sid), do: Enum.at(@ports, sid - 1)

  def init(_args) do
    :ets.new(@table_name, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    socks =
      @ports
      |> Enum.with_index(1)
      |> Enum.map(fn {port, x} ->
        {x, Socket.TCP.connect!({@remote, port})}
      end)

    Enum.map(socks, fn {x, sock} ->
      :ets.insert(@table_name, {x, {sock, :alive, ""}})
    end)

    start_serve(socks)

    1..Enum.count(@ports)
    |> Enum.each(fn x -> Process.send_after(self(), {:keepalive, x}, 1000) end)

    {:ok, %{size: Enum.count(@ports)}}
  end

  def handle_cast({:send, data}, state) do
    {sid, sock} = random_socket(state.size, 3)
    Socket.Stream.send(sock, <<2::size(8), sid::size(8)>> <> data)
    {:noreply, state}
  end

  defp random_socket(_, 0), do: nil

  defp random_socket(size, rest) do
    x = Enum.random(1..size)

    case get_socket(x) do
      nil -> random_socket(size, rest - 1)
      {sock, _, _} -> {x, sock}
    end
  end

  defp get_socket(socket_id) do
    case :ets.lookup(@table_name, socket_id) do
      [] -> nil
      [{_, sock}] -> sock
    end
  end

  defp start_serve([]), do: :ok

  defp start_serve([{sid, sock} | t]) do
    Task.start(fn -> serve(sid, sock) end)
    start_serve(t)
  end

  def handle_info({:keepalive, socket_id}, state) do
    case get_socket(socket_id) do
      {sock, :alive, _} ->
        # check alive
        cookie = random_string(5)
        Socket.Stream.send(sock, <<1::size(8), socket_id::size(8)>> <> cookie)
        :ets.insert(@table_name, {socket_id, {sock, :wait, cookie}})

      _ ->
        # dead or wait
        sock = Socket.TCP.connect!({@remote, get_port(socket_id)})
        :ets.insert(@table_name, {socket_id, {sock, :alive, ""}})
        Task.start(fn -> serve(socket_id, sock) end)
    end

    Process.send_after(self(), {:keepalive, socket_id}, @pingpong_ttl)

    {:noreply, state}
  end

  defp serve(sid, socket) do
    case Socket.Stream.recv(socket) do
      {:ok, data} when data != nil ->
        process(data)
        serve(sid, socket)

      reason ->
        Logger.warn("socket closed for #{inspect(reason)}")
        Socket.Stream.close(socket)
        :ets.delete(@table_name, sid)
    end
  end

  defp process(<<1::size(8), sid::size(8), cookie::binary>>) do
    # set socket alive
    # Logger.info("#{sid}: pong!")

    case get_socket(sid) do
      {sock, :wait, local_cookie} when <<cookie::binary>> == local_cookie ->
        # set alive
        :ets.insert(@table_name, {sid, {sock, :alive, ""}})

      {_sock, :alive, _} ->
        # do nothing
        nil

      _ ->
        raise "bad record"
    end
  end

  defp process(<<2::size(8), _sid::size(8), data::binary>>),
    do: IO.puts("response: #{<<data::binary>>}")

  defp process(data), do: Logger.warn("I cannot understand #{inspect(data)}")

  defp random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
    |> binary_part(0, length)
  end
end
