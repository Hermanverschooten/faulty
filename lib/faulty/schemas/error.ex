defmodule Faulty.Error do
  @moduledoc """
  Schema to store an error or exception recorded by Faulty.

  It stores a kind, reason and source code location to generate a unique
  fingerprint that can be used to avoid duplicates.

  The fingerprint includes a normalized version of the error reason to ensure
  proper grouping of similar errors while separating different error types.
  See `Faulty.Fingerprint` for the fingerprinting algorithm details.
  """

  @type status :: :resolved | :unresolved

  @type t :: %__MODULE__{
          kind: String.t() | nil,
          reason: String.t() | nil,
          source_line: String.t() | nil,
          source_function: String.t() | nil,
          status: status(),
          fingerprint: String.t() | nil,
          last_occurrence_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder,
           only: [
             :kind,
             :reason,
             :source_line,
             :source_function,
             :status,
             :fingerprint,
             :last_occurrence_at
           ]}

  defstruct kind: nil,
            reason: nil,
            source_line: nil,
            source_function: nil,
            status: :unresolved,
            fingerprint: nil,
            last_occurrence_at: nil

  @doc false
  @spec new(term(), String.t(), Faulty.Stacktrace.t()) :: {:ok, t()}
  def new(kind, reason, stacktrace = %Faulty.Stacktrace{}) do
    source = Faulty.Stacktrace.source(stacktrace)

    {source_line, source_function} =
      if source do
        source_line = if source.line, do: "#{source.file}:#{source.line}", else: "(nofile)"
        source_function = "#{source.module}.#{source.function}/#{source.arity}"

        {source_line, source_function}
      else
        {"-", "-"}
      end

    kind = to_string(kind)

    {:ok,
     %__MODULE__{
       kind: kind,
       reason: reason,
       source_line: source_line,
       source_function: source_function,
       fingerprint: Faulty.Fingerprint.generate(kind, reason, source_line, source_function),
       last_occurrence_at: DateTime.utc_now()
     }}
  end

  @doc """
  Returns if the Error has information of the source or not.

  Errors usually have information about in which line and function occurred, but
  in some cases (like an Oban job ending with `{:error, any()}`) we cannot get
  that information and no source is stored.
  """
  def has_source_info?(%__MODULE__{source_function: "-", source_line: "-"}), do: false
  def has_source_info?(%__MODULE__{}), do: true
end
