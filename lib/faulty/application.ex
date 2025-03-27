defmodule Faulty.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    set_url()

    children =
      [Faulty.Reporter] ++
        Application.get_env(:faulty, :plugins, [])

    attach_handlers()

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  defp attach_handlers do
    Faulty.Integrations.Quantum.attach()
    Faulty.Integrations.Oban.attach()
    Faulty.Integrations.Phoenix.attach()
    Faulty.LoggerHandler.attach()
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
