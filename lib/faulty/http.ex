defmodule Faulty.Http do
  @moduledoc false
  require Logger

  @profile :faulty
  @default_connect_timeout 30_000
  @default_receive_timeout 15_000
  @supported_connect_options [:transport_opts, :timeout, :proxy]

  @spec start_profile() :: :ok
  def start_profile do
    case :inets.start(:httpc, profile: @profile) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    apply_proxy(Application.get_env(:faulty, :connect_options, []))
  end

  @spec stop_profile() :: :ok
  def stop_profile do
    :inets.stop(:httpc, @profile)
    :ok
  end

  @spec post(String.t(), iodata()) :: {:ok, non_neg_integer()} | {:error, term()}
  def post(url, body) do
    connect_options = Application.get_env(:faulty, :connect_options, [])

    request =
      {String.to_charlist(url), [{~c"accept", ~c"application/json"}], ~c"application/json", body}

    http_options = [
      timeout: Application.get_env(:faulty, :receive_timeout, @default_receive_timeout),
      connect_timeout: Keyword.get(connect_options, :timeout, @default_connect_timeout),
      ssl: ssl_options(url, connect_options)
    ]

    case :httpc.request(:post, request, http_options, [body_format: :binary], @profile) do
      {:ok, {{_version, status, _reason}, _headers, _body}} -> {:ok, status}
      {:error, reason} -> {:error, reason}
    end
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  @spec warn_about_ignored_config() :: :ok
  def warn_about_ignored_config do
    if Application.get_env(:faulty, :retries) do
      Logger.warning(
        "Faulty: the :retries option is no longer used, errors are retried by the queue, see :retry_interval"
      )
    end

    if Application.get_env(:faulty, :req_options) do
      Logger.warning("Faulty: the :req_options option is no longer used, Req is not a dependency")
    end

    connect_options = Application.get_env(:faulty, :connect_options, [])

    case Keyword.keys(connect_options) -- @supported_connect_options do
      [] ->
        :ok

      ignored ->
        Logger.warning(
          "Faulty: ignoring the unsupported :connect_options #{inspect(ignored)}, " <>
            "supported are #{inspect(@supported_connect_options)}"
        )
    end
  end

  defp ssl_options("https://" <> _rest, connect_options) do
    transport_opts = Keyword.get(connect_options, :transport_opts, [])

    trust =
      if Keyword.has_key?(transport_opts, :cacerts) or
           Keyword.has_key?(transport_opts, :cacertfile),
         do: [],
         else: [cacerts: :public_key.cacerts_get()]

    Keyword.merge([verify: :verify_peer] ++ trust, transport_opts)
  end

  defp ssl_options(_url, _connect_options), do: []

  defp apply_proxy(connect_options) do
    case Keyword.get(connect_options, :proxy) do
      {_scheme, host, port, _opts} ->
        proxy = {{to_charlist(host), port}, []}
        :ok = :httpc.set_options([proxy: proxy, https_proxy: proxy], @profile)

      _none ->
        :ok
    end
  end
end
