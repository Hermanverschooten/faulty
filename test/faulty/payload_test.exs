defmodule Faulty.PayloadTest do
  use ExUnit.Case

  alias Faulty.Payload

  @stack [
    {Faulty, :report, 3, [file: ~c"lib/faulty.ex", line: 10]},
    {:erlang, :apply, 2, []}
  ]

  defp report(context \\ %{}) do
    {:ok, stacktrace} = Faulty.Stacktrace.new(@stack)
    {:ok, error} = Faulty.Error.new("Elixir.ArgumentError", "boom", stacktrace)

    %{error: error, stacktrace: stacktrace, context: context, reason: "boom"}
  end

  defp structs(term) when is_struct(term), do: [term.__struct__]
  defp structs(term) when is_map(term), do: term |> Map.values() |> Enum.flat_map(&structs/1)
  defp structs(term) when is_list(term), do: Enum.flat_map(term, &structs/1)
  defp structs(_term), do: []

  describe "build/1" do
    test "has the four top level keys" do
      assert report() |> Payload.build() |> Map.keys() |> Enum.sort() ==
               ~w(context error reason stacktrace)
    end

    test "contains only plain data, no structs" do
      assert report() |> Payload.build() |> structs() == []
    end

    test "formats the timestamp as an ISO 8601 string and the status as a string" do
      %{"error" => error} = Payload.build(report())

      assert is_binary(error["last_occurrence_at"])
      assert {:ok, _, 0} = DateTime.from_iso8601(error["last_occurrence_at"])
      assert error["status"] == "unresolved"
    end

    test "keeps the fields of an error" do
      %{error: error} = report = report()
      %{"error" => built} = Payload.build(report)

      assert built["kind"] == "Elixir.ArgumentError"
      assert built["reason"] == "boom"
      assert built["source_line"] == error.source_line
      assert built["source_function"] == error.source_function
      assert built["fingerprint"] == error.fingerprint
    end

    test "builds a line per stack entry, with nil for what is unknown" do
      %{"stacktrace" => %{"lines" => [first, second]}} = Payload.build(report())

      assert first == %{
               "application" => "faulty",
               "module" => "Faulty",
               "function" => "report",
               "arity" => 3,
               "file" => "lib/faulty.ex",
               "line" => 10
             }

      assert %{"application" => nil, "file" => nil, "line" => nil} = second
    end

    test "passes the context through untouched" do
      context = %{"user_id" => 1, "nested" => %{"a" => [1, 2]}, "at" => ~U[2026-01-01 00:00:00Z]}

      assert %{"context" => ^context} = Payload.build(report(context))
    end

    test "encodes to the same json with every library" do
      payload = Payload.build(report(%{"user_id" => 1}))

      assert payload |> JSON.encode!() |> JSON.decode!() ==
               payload |> Jason.encode!() |> Jason.decode!()
    end
  end
end
