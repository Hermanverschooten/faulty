defmodule Faulty.LoggerHandler do
  @moduledoc false

  @handler_id Faulty

  @own_logs_domain [:faulty, :logger_handler]

  require Logger

  @spec attach() :: :ok | {:error, term()}
  def attach do
    :logger.add_handler(
      @handler_id,
      __MODULE__,
      %{
        level: :all,
        filters: [
          own_log_filters: {
            &:logger_filters.domain/2,
            {:stop, :sub, [:elixir | @own_logs_domain]}
          }
        ]
      }
    )
  end

  @spec detach() :: :ok | {:error, term()}
  def detach do
    :logger.remove_handler(@handler_id)
  end

  # :logger callbacks

  def adding_handler(config), do: {:ok, config}
  def removing_handler(_config), do: :ok

  def log(log_event, _config) do
    handle_log_event(log_event)
  end

  defp handle_log_event(%{
         level: :error,
         meta: %{
           crash_reason: {
             %{
               kind: :error,
               reason: reason,
               stack: stacktrace
             },
             stacktrace
           }
         }
       }) do
    Faulty.report(Exception.normalize(:error, reason, stacktrace), stacktrace)
  end

  defp handle_log_event(%{level: :error, meta: %{crash_reason: {exception, stacktrace}}})
       when is_exception(exception) and is_list(stacktrace) do
    Faulty.report(exception, stacktrace)
    |> dbg()
  end

  defp handle_log_event(%{level: :error, meta: %{crash_reason: {{:nocatch, reason}, stacktrace}}})
       when is_list(stacktrace) do
    Faulty.report(reason, stacktrace)
  end

  defp handle_log_event(%{level: :error, meta: %{crash_reason: {exit_reason, stacktrace}}})
       when is_list(stacktrace) do
    Faulty.report({:error, exit_reason}, stacktrace)
  end

  defp handle_log_event(%{level: :error, meta: %{crash_reason: exit_reason}}) do
    Faulty.report({:error, exit_reason}, [])
  end

  defp handle_log_event(_) do
  end
end
