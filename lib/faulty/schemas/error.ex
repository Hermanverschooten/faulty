defmodule Faulty.Error do
  @moduledoc """
  Schema to store an error or exception recorded by Faulty.

  It stores a kind, reason and source code location to generate a unique
  fingerprint that can be used to avoid duplicates.

  The fingerprint includes a normalized version of the error reason to ensure
  proper grouping of similar errors while separating different error types.
  See `Faulty.Fingerprint` for the fingerprinting algorithm details.
  """

  use Ecto.Schema

  @type t :: %__MODULE__{}

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

  schema "faulty_errors" do
    field(:kind, :string)
    field(:reason, :string)
    field(:source_line, :string)
    field(:source_function, :string)
    field(:status, Ecto.Enum, values: [:resolved, :unresolved], default: :unresolved)
    field(:fingerprint, :binary)
    field(:last_occurrence_at, :utc_datetime_usec)
  end

  @doc false
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

    params = [
      kind: to_string(kind),
      source_line: source_line,
      source_function: source_function
    ]

    fingerprint =
      Faulty.Fingerprint.generate(to_string(kind), reason, source_line, source_function)

    %__MODULE__{}
    |> Ecto.Changeset.change(params)
    |> Ecto.Changeset.put_change(:reason, reason)
    |> Ecto.Changeset.put_change(:fingerprint, fingerprint)
    |> Ecto.Changeset.put_change(:last_occurrence_at, DateTime.utc_now())
    |> Ecto.Changeset.apply_action(:new)
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
