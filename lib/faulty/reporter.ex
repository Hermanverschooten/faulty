defmodule Faulty.Reporter do
  use GenServer
  require Logger
  @moduledoc false

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send(error, stacktrace, context, reason) do
    GenServer.cast(
      __MODULE__,
      {:report, %{error: error, stacktrace: stacktrace, context: context, reason: reason}}
    )
  end

  @impl true
  def init(_opts) do
    {:ok, %{url: get_url(), errors: :ets.new(__MODULE__, [:ordered_set])}}
  end

  @impl true
  def handle_cast({:report, error}, state) do
    :ets.insert(state.errors, {System.monotonic_time(), error})
    Logger.debug("Faulty: new error added to queue")
    {:noreply, state, {:continue, :process}}
  end

  @impl true
  def handle_continue(:process, state) do
    case :ets.match(state.errors, :"$1") do
      [] ->
        Logger.debug("Faulty: Queue is empty.")
        {:noreply, state}

      [[{id, error}] | _] ->
        Logger.debug("Faulty: Processing first error in queue.")

        case Req.post(state.url,
               json: error,
               connect_options: Application.get_env(:faulty, :connect_options, []),
               retry: :transient,
               max_retries: Application.get_env(:faulty, :retries, 5)
             ) do
          {:ok, %{status: 200}} ->
            Logger.debug("Faulty: Error sent")
            :ets.delete(state.errors, id)
            {:noreply, state, {:continue, :process}}

          _ ->
            Logger.debug("Faulty: Error could not be sent, retrying in 1 minute")
            {:noreply, state, :timer.minutes(1)}
        end
    end
  end

  @impl true
  def handle_info(:timeout, state) do
    {:noreply, state, {:continue, :process}}
  end

  defp get_url do
    Application.get_env(:faulty, :env, "FAULTY_TOWER_URL")
    |> System.get_env()
  end
end
