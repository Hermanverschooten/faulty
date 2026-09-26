defmodule Faulty.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    set_url()
    Faulty.Http.warn_about_ignored_config()
    Faulty.Http.start_profile()

    children =
      [{Task.Supervisor, name: Faulty.TaskSupervisor}, Faulty.Reporter] ++
        Application.get_env(:faulty, :plugins, [])

    attach_handlers()

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  @impl true
  def stop(_state), do: Faulty.Http.stop_profile()

  defp attach_handlers do
    Faulty.Integrations.Quantum.attach()
    Faulty.Integrations.Oban.attach()

    attach_phoenix()
    Faulty.LoggerHandler.attach()
  end

  if Code.ensure_loaded?(Plug.Conn) do
    defp attach_phoenix, do: Faulty.Integrations.Phoenix.attach()
  else
    defp attach_phoenix, do: :ok
  end

  defp set_url do
    if Application.get_env(:faulty, :enabled, false) do
      envvar = Application.get_env(:faulty, :env, "FAULTY_TOWER_URL")

      if !System.get_env(envvar) do
        raise ArgumentError, "#{envvar} environment variable is not set!"
      end
    end
  end
end
