defmodule Faulty.Payload do
  @moduledoc false

  alias Faulty.Error
  alias Faulty.Stacktrace

  @spec build(%{
          error: Error.t(),
          stacktrace: Stacktrace.t(),
          context: map(),
          reason: term()
        }) :: map()
  def build(%{error: error, stacktrace: stacktrace, context: context, reason: reason}) do
    %{
      "error" => error(error),
      "reason" => reason,
      "context" => context,
      "stacktrace" => stacktrace(stacktrace)
    }
  end

  defp error(%Error{} = error) do
    %{
      "kind" => error.kind,
      "reason" => error.reason,
      "source_line" => error.source_line,
      "source_function" => error.source_function,
      "status" => Atom.to_string(error.status),
      "fingerprint" => error.fingerprint,
      "last_occurrence_at" => DateTime.to_iso8601(error.last_occurrence_at)
    }
  end

  defp stacktrace(%Stacktrace{lines: lines}) do
    %{"lines" => Enum.map(lines, &line/1)}
  end

  defp line(%Stacktrace.Line{} = line) do
    %{
      "application" => line.application,
      "module" => line.module,
      "function" => line.function,
      "arity" => line.arity,
      "file" => line.file,
      "line" => line.line
    }
  end
end
