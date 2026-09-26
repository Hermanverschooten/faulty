defmodule Faulty.Stacktrace do
  @moduledoc """
  An Stacktrace contains the information about the execution stack for a given
  occurrence of an exception.
  """

  defmodule Line do
    @moduledoc """
    A single entry of a `Faulty.Stacktrace`.
    """

    @type t :: %__MODULE__{
            application: String.t() | nil,
            module: String.t() | nil,
            function: String.t() | nil,
            arity: non_neg_integer() | nil,
            file: String.t() | nil,
            line: non_neg_integer() | nil
          }

    @derive {Jason.Encoder, only: [:application, :module, :function, :arity, :file, :line]}

    defstruct [:application, :module, :function, :arity, :file, :line]
  end

  @type t :: %__MODULE__{lines: [Line.t()]}

  @derive {Jason.Encoder, only: [:lines]}

  defstruct lines: []

  @spec new(Exception.stacktrace()) :: {:ok, t()}
  def new(stack) do
    lines =
      for {module, function, arity, opts} <- stack do
        application = Application.get_application(module)

        %Line{
          application: blank_to_nil(to_string(application)),
          module: module |> to_string() |> String.replace_prefix("Elixir.", ""),
          function: to_string(function),
          arity: normalize_arity(arity),
          file: blank_to_nil(to_string(opts[:file])),
          line: opts[:line]
        }
      end

    {:ok, %__MODULE__{lines: lines}}
  end

  defp normalize_arity(a) when is_integer(a), do: a
  defp normalize_arity(a) when is_list(a), do: length(a)

  defp blank_to_nil(string) do
    if String.trim(string) == "", do: nil, else: string
  end

  @doc """
  Source of the error stack trace.

  The first line matching the client application. If no line belongs to the current
  application, just the first line.
  """
  def source(stack = %__MODULE__{}) do
    client_app = Application.fetch_env!(:faulty, :otp_app)

    Enum.find(stack.lines, &(&1.application == client_app)) || List.first(stack.lines)
  end
end

defimpl String.Chars, for: Faulty.Stacktrace do
  def to_string(stack = %Faulty.Stacktrace{}) do
    Enum.join(stack.lines, "\n")
  end
end

defimpl String.Chars, for: Faulty.Stacktrace.Line do
  def to_string(stack_line = %Faulty.Stacktrace.Line{}) do
    "#{stack_line.module}.#{stack_line.function}/#{stack_line.arity} in #{stack_line.file}:#{stack_line.line}"
  end
end
