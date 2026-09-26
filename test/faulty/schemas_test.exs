defmodule Faulty.SchemasTest do
  use ExUnit.Case

  alias Faulty.Error
  alias Faulty.Stacktrace

  @stack [
    {Faulty, :report, 3, [file: ~c"lib/faulty.ex", line: 10]},
    {Enum, :map, [:a, :b], [file: ~c"lib/enum.ex", line: 20]},
    {:erlang, :apply, 2, []}
  ]

  describe "Faulty.Stacktrace.new/1" do
    test "builds a line per stack entry" do
      assert {:ok, %Stacktrace{lines: [first, second, third]}} = Stacktrace.new(@stack)

      assert %Stacktrace.Line{
               application: "faulty",
               module: "Faulty",
               function: "report",
               arity: 3,
               file: "lib/faulty.ex",
               line: 10
             } == first

      assert %Stacktrace.Line{module: "Enum", function: "map", arity: 2, line: 20} = second

      assert %Stacktrace.Line{
               application: nil,
               module: "erlang",
               function: "apply",
               arity: 2,
               file: nil,
               line: nil
             } == third
    end

    test "accepts an empty stacktrace" do
      assert {:ok, %Stacktrace{lines: []}} = Stacktrace.new([])
    end

    test "encodes to json with only the lines and their fields" do
      {:ok, stacktrace} = Stacktrace.new(@stack)

      assert %{"lines" => [first | _]} = stacktrace |> Jason.encode!() |> Jason.decode!()

      assert first == %{
               "application" => "faulty",
               "module" => "Faulty",
               "function" => "report",
               "arity" => 3,
               "file" => "lib/faulty.ex",
               "line" => 10
             }
    end

    test "converts to a string" do
      {:ok, stacktrace} = Stacktrace.new(@stack)

      assert to_string(stacktrace) |> String.starts_with?("Faulty.report/3 in lib/faulty.ex:10\n")
    end
  end

  describe "Faulty.Stacktrace.source/1" do
    @library_first [
      {Enum, :map, 2, [file: ~c"lib/enum.ex", line: 1]},
      {Faulty, :report, 3, [file: ~c"lib/faulty.ex", line: 10]},
      {Plug, :call, 2, [file: ~c"lib/plug.ex", line: 5]}
    ]

    test "picks the first line that belongs to the client application" do
      {:ok, stacktrace} = Stacktrace.new(@library_first)

      assert %Stacktrace.Line{module: "Faulty", function: "report"} =
               Stacktrace.source(stacktrace)
    end

    test "accepts the client application as a string" do
      original = Application.fetch_env!(:faulty, :otp_app)
      Application.put_env(:faulty, :otp_app, "faulty")
      on_exit(fn -> Application.put_env(:faulty, :otp_app, original) end)

      {:ok, stacktrace} = Stacktrace.new(@library_first)

      assert %Stacktrace.Line{module: "Faulty"} = Stacktrace.source(stacktrace)
    end

    test "falls back to the first line when none belongs to the client application" do
      {:ok, stacktrace} = Stacktrace.new([hd(@library_first), List.last(@library_first)])

      assert %Stacktrace.Line{module: "Enum"} = Stacktrace.source(stacktrace)
    end

    test "returns nil for an empty stacktrace" do
      {:ok, stacktrace} = Stacktrace.new([])

      assert Stacktrace.source(stacktrace) == nil
    end
  end

  describe "Faulty.Error.new/3" do
    test "builds an unresolved error with a fingerprint and timestamp" do
      {:ok, stacktrace} = Stacktrace.new(@stack)

      assert {:ok, %Error{} = error} = Error.new("Elixir.ArgumentError", "boom", stacktrace)

      assert error.kind == "Elixir.ArgumentError"
      assert error.reason == "boom"
      assert error.source_line == "lib/faulty.ex:10"
      assert error.source_function == "Faulty.report/3"
      assert error.status == :unresolved
      assert is_binary(error.fingerprint)
      assert %DateTime{} = error.last_occurrence_at
    end

    test "takes the source from the client application, not from library code" do
      {:ok, stacktrace} =
        Stacktrace.new([
          {Enum, :map, 2, [file: ~c"lib/enum.ex", line: 1]},
          {Faulty, :report, 3, [file: ~c"lib/faulty.ex", line: 10]}
        ])

      {:ok, error} = Error.new("error", "boom", stacktrace)

      assert error.source_line == "lib/faulty.ex:10"
      assert error.source_function == "Faulty.report/3"
    end

    test "has no source information without a stacktrace" do
      {:ok, stacktrace} = Stacktrace.new([])

      assert {:ok, error} = Error.new("error", "boom", stacktrace)

      refute Error.has_source_info?(error)
      assert {error.source_line, error.source_function} == {"-", "-"}
    end

    test "encodes to json with exactly the fields FaultyTower expects" do
      {:ok, stacktrace} = Stacktrace.new(@stack)
      {:ok, error} = Error.new("Elixir.ArgumentError", "boom", stacktrace)

      json = error |> Jason.encode!() |> Jason.decode!()

      assert Map.keys(json) |> Enum.sort() ==
               ~w(fingerprint kind last_occurrence_at reason source_function source_line status)

      assert json["status"] == "unresolved"
      assert json["fingerprint"] == error.fingerprint
      assert {:ok, _, _} = DateTime.from_iso8601(json["last_occurrence_at"])
    end
  end
end
