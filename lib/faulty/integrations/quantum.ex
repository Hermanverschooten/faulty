defmodule Faulty.Integrations.Quantum do
  @moduledoc """
  Integration with Quantum.

  ## How to use it

  It is a plug and play integration: as long as you have Quantum installed the
  Faulty will receive and store the errors as they are reported.

  ### How it works

  It works using Quantum's Telemetry events, so you don't need to modify anything
  on your application.
  """

  require Logger

  @events [
    [:quantum, :job, :start],
    [:quantum, :job, :exception]
  ]

  def attach do
    if Application.spec(:quantum) do
      :telemetry.attach_many(__MODULE__, @events, &__MODULE__.handle_event/4, :no_config)
    end
  end

  def handle_event([:quantum, :job, :start], _measurements, metadata, :no_config) do
    %{job: job} = metadata

    Faulty.set_context(%{
      "node" => inspect(metadata.node),
      "scheduler" => inspect(metadata.scheduler),
      "run_strategy" => inspect(job.run_strategy),
      "overlap" => job.overlap,
      "timezone" => job.timezone,
      "name" => name(job),
      "schedule" => inspect(job.schedule),
      "task" => inspect(job.task)
    })
  end

  def handle_event([:quantum, :job, :exception], _measurements, metadata, :no_config) do
    %{reason: reason, stacktrace: stacktrace} = metadata
    kind = Map.get(metadata, :kind, :error)

    Faulty.report({kind, reason}, stacktrace)
  end

  ## Helpers

  defp name(%{name: name}) when is_reference(name), do: "anonymous"
  defp name(%{name: name}), do: name
end
