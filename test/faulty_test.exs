defmodule FaultyTest do
  use ExUnit.Case
  doctest Faulty

  setup do
    original_enabled = Application.get_env(:faulty, :enabled, true)
    original_filter = Application.get_env(:faulty, :filter)
    original_ignorer = Application.get_env(:faulty, :ignorer)

    on_exit(fn ->
      Application.put_env(:faulty, :enabled, original_enabled)
      Application.put_env(:faulty, :filter, original_filter)
      Application.put_env(:faulty, :ignorer, original_ignorer)
      Process.delete(:faulty_context)
      Process.delete(:faulty_error_reported)
    end)

    :ok
  end

  describe "report/3" do
    test "reports an exception with stacktrace" do
      result = report_error(fn -> raise ArgumentError, "test error" end)
      assert result == :ok
    end

    test "reports a throw with stacktrace" do
      result = report_error(fn -> throw(:test_throw) end)
      assert result == :ok
    end

    test "reports an exit with stacktrace" do
      result = report_error(fn -> exit(:test_exit) end)
      assert result == :ok
    end

    test "returns :noop when disabled" do
      Application.put_env(:faulty, :enabled, false)

      result = report_error(fn -> raise ArgumentError, "test error" end)
      assert result == :noop
    end

    test "includes given context in error report" do
      context = %{"user_id" => 123, "request_id" => "abc"}

      result = report_error(fn -> raise ArgumentError, "test error" end, context)
      assert result == :ok
    end

    test "merges given context with process context" do
      Faulty.set_context(%{"process_key" => "process_value"})
      context = %{"call_key" => "call_value"}

      result = report_error(fn -> raise ArgumentError, "test error" end, context)
      assert result == :ok
    end

    test "prevents duplicate error reporting in same process" do
      assert report_error(fn -> raise ArgumentError, "first error" end) == :ok
      assert report_error(fn -> raise ArgumentError, "second error" end) == :noop
    end

    test "handles breadcrumbs from exception" do
      exception = %ArgumentError{message: "test"} |> Map.put(:bread_crumbs, ["step1", "step2"])

      result =
        try do
          raise exception
        rescue
          e -> Faulty.report(e, __STACKTRACE__)
        end

      assert result == :ok
    end
  end

  describe "message/2" do
    test "reports a binary message" do
      result = Faulty.message("Test error message")
      assert result == :ok
    end

    test "reports an exception struct" do
      result = Faulty.message(%ArgumentError{message: "test error"})
      assert result == :ok
    end

    test "reports a {kind, reason} tuple" do
      result = Faulty.message({:error, "test error"})
      assert result == :ok
    end

    test "includes context in message report" do
      context = %{"user_id" => 456}
      result = Faulty.message("Test error", context)
      assert result == :ok
    end

    test "returns :noop for invalid input" do
      result = Faulty.message(123)
      assert result == :noop
    end
  end

  describe "context management" do
    test "set_context/1 sets process context" do
      context = %{"user_id" => 123, "session" => "abc"}

      result = Faulty.set_context(context)
      assert result == context
      assert Faulty.get_context() == context
    end

    test "set_context/1 merges with existing context" do
      Faulty.set_context(%{"key1" => "value1"})
      Faulty.set_context(%{"key2" => "value2"})

      expected = %{"key1" => "value1", "key2" => "value2"}
      assert Faulty.get_context() == expected
    end

    test "set_context/1 overwrites existing keys" do
      Faulty.set_context(%{"key" => "original"})
      Faulty.set_context(%{"key" => "updated"})

      assert Faulty.get_context() == %{"key" => "updated"}
    end

    test "get_context/0 returns empty map when no context set" do
      assert Faulty.get_context() == %{}
    end
  end

  describe "filtering and ignoring" do
    defmodule TestFilter do
      @behaviour Faulty.Filter

      def sanitize(context) do
        Map.update(context, "password", nil, fn _ -> "[REDACTED]" end)
      end
    end

    defmodule TestIgnorer do
      @behaviour Faulty.Ignorer

      def ignore?(_error, context) do
        Map.get(context, "ignore", false)
      end
    end

    test "applies filter to sanitize context" do
      Application.put_env(:faulty, :filter, TestFilter)

      context = %{"password" => "secret123"}
      result = report_error(fn -> raise ArgumentError, "test error" end, context)
      assert result == :ok
    end

    test "ignores errors when ignorer returns true" do
      Application.put_env(:faulty, :ignorer, TestIgnorer)

      context = %{"ignore" => true}
      result = report_error(fn -> raise ArgumentError, "test error" end, context)
      assert result == :noop
    end

    test "reports errors when ignorer returns false" do
      Application.put_env(:faulty, :ignorer, TestIgnorer)

      context = %{"ignore" => false}
      result = report_error(fn -> raise ArgumentError, "test error" end, context)
      assert result == :ok
    end
  end

  defp report_error(fun, context \\ %{}) do
    try do
      fun.()
    rescue
      exception ->
        Faulty.report(exception, __STACKTRACE__, context)
    catch
      kind, reason ->
        Faulty.report({kind, reason}, __STACKTRACE__, context)
    end
  end
end
