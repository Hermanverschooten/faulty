defmodule Faulty.Reporter do
  use GenServer
  require Logger
  @moduledoc false

  @default_queue_size 1000
  @default_retry_interval :timer.minutes(1)

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
    {:ok, %{errors: :ets.new(__MODULE__, [:ordered_set]), delivering: nil, retry_timer: nil}}
  end

  @impl true
  def handle_cast({:report, error}, state) do
    if :ets.info(state.errors, :size) >= queue_size() do
      Logger.debug("Faulty: queue is full, dropping error")
      {:noreply, state}
    else
      :ets.insert(state.errors, {System.unique_integer([:monotonic]), error})
      Logger.debug("Faulty: new error added to queue")
      {:noreply, deliver_next(state)}
    end
  end

  @impl true
  def handle_info({ref, result}, %{delivering: {ref, id}} = state) do
    Process.demonitor(ref, [:flush])
    handle_result(result, id, %{state | delivering: nil})
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{delivering: {ref, id}} = state) do
    handle_result(:retry, id, %{state | delivering: nil})
  end

  def handle_info(:retry, state) do
    {:noreply, deliver_next(%{state | retry_timer: nil})}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp handle_result(:retry, _id, state) do
    Logger.debug("Faulty: Error could not be sent, retrying later")
    timer = Process.send_after(self(), :retry, retry_interval())
    {:noreply, %{state | retry_timer: timer}}
  end

  defp handle_result(_delivered_or_dropped, id, state) do
    :ets.delete(state.errors, id)
    {:noreply, deliver_next(state)}
  end

  defp deliver_next(%{delivering: delivering} = state) when delivering != nil, do: state
  defp deliver_next(%{retry_timer: timer} = state) when timer != nil, do: state

  defp deliver_next(state) do
    case :ets.first(state.errors) do
      :"$end_of_table" ->
        Logger.debug("Faulty: Queue is empty.")
        state

      id ->
        [{^id, error}] = :ets.lookup(state.errors, id)
        Logger.debug("Faulty: Processing first error in queue.")

        task = Task.Supervisor.async_nolink(Faulty.TaskSupervisor, fn -> deliver(error) end)
        %{state | delivering: {task.ref, id}}
    end
  end

  defp deliver(error) do
    case get_url() do
      nil ->
        Logger.debug("Faulty: No url configured, dropping error")
        :drop

      url ->
        post(url, error)
    end
  rescue
    exception ->
      Logger.debug("Faulty: Error could not be delivered: #{Exception.message(exception)}")
      :drop
  catch
    kind, reason ->
      Logger.debug("Faulty: Error could not be delivered: #{inspect({kind, reason})}")
      :drop
  end

  defp post(url, error) do
    case Faulty.Http.post(url, Jason.encode!(error)) do
      {:ok, status} when status in 200..299 ->
        Logger.debug("Faulty: Error sent")
        :ok

      {:ok, status} when status in [408, 429] or status >= 500 ->
        :retry

      {:ok, status} ->
        Logger.debug("Faulty: Error rejected with status #{status}, dropping")
        :drop

      {:error, _reason} ->
        :retry
    end
  end

  defp queue_size, do: Application.get_env(:faulty, :queue_size, @default_queue_size)

  defp retry_interval, do: Application.get_env(:faulty, :retry_interval, @default_retry_interval)

  defp get_url do
    Application.get_env(:faulty, :env, "FAULTY_TOWER_URL")
    |> System.get_env()
  end
end
