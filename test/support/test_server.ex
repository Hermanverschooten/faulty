defmodule Faulty.TestServer do
  @moduledoc false
  @behaviour Plug

  import Plug.Conn

  @doc """
  Starts a real local HTTP server, linked to the calling process.

  `handler` receives a map with the request `:body`, `:method`, `:host`, `:path` and
  `:headers` and returns the response status. It runs in the process that serves the
  request. Pass `tls: server_config` (from `:public_key.pkix_test_data/1`) to serve HTTPS.
  """
  def start(handler, opts \\ []) do
    {scheme, tls_options} =
      case Keyword.get(opts, :tls) do
        nil -> {:http, []}
        server_config -> {:https, [thousand_island_options: [transport_options: server_config]]}
      end

    {:ok, pid} =
      Bandit.start_link(
        [
          plug: {__MODULE__, handler},
          scheme: scheme,
          port: 0,
          ip: :loopback,
          startup_log: false
        ] ++ tls_options
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(pid)

    %{pid: pid, port: port, url: "#{scheme}://127.0.0.1:#{port}/api/errors"}
  end

  @doc "A url on a local port that nothing is listening on."
  def dead_url do
    {:ok, listener} = :gen_tcp.listen(0, [])
    {:ok, port} = :inet.port(listener)
    :gen_tcp.close(listener)

    "http://127.0.0.1:#{port}/api/errors"
  end

  @impl Plug
  def init(handler), do: handler

  @impl Plug
  def call(conn, handler) do
    {:ok, body, conn} = read_body(conn)

    status =
      handler.(%{
        body: body,
        method: conn.method,
        host: conn.host,
        path: conn.request_path,
        headers: Map.new(conn.req_headers)
      })

    send_resp(conn, status, "")
  end
end
