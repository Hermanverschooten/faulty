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
  end

  defp set_url do
    if Application.get_env(:faulty, :enabled, false) do
      if !Application.get_env(:faulty, :faulty_tower_url) do
        raise ArgumentError, ":faulty_tower_url is not set in your config!"
      end
    end
  end
end
