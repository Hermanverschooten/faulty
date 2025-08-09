defmodule Faulty.IgnorerTest do
  use ExUnit.Case

  alias Faulty.Error

  setup do
    {:ok, stacktrace} = Faulty.Stacktrace.new([])
    {:ok, error} = Error.new("Elixir.ArgumentError", "production error", stacktrace)

    %{error: error}
  end

  describe "Ignorer behaviour" do
    defmodule TestIgnorer do
      @behaviour Faulty.Ignorer

      def ignore?(error, context) do
        String.contains?(error.reason, "[IGNORE]") or
          Map.get(context, "ignore", false)
      end
    end

    test "defines ignore?/2 callback" do
      assert Faulty.Ignorer.behaviour_info(:callbacks) == [{:ignore?, 2}]
    end

    test "can ignore errors based on error content", %{error: error} do
      ignored_error = %{error | reason: "[IGNORE] This should be ignored"}
      context = %{}

      assert TestIgnorer.ignore?(ignored_error, context) == true
      assert TestIgnorer.ignore?(error, context) == false
    end

    test "can ignore errors based on context", %{error: error} do
      ignore_context = %{"ignore" => true}
      normal_context = %{"ignore" => false}

      assert TestIgnorer.ignore?(error, ignore_context) == true
      assert TestIgnorer.ignore?(error, normal_context) == false
    end
  end

  describe "Common ignorer patterns" do
    defmodule DevelopmentIgnorer do
      @behaviour Faulty.Ignorer

      def ignore?(error, context) do
        # Ignore test/development related errors
        is_test_error?(error) or is_development_context?(context)
      end

      defp is_test_error?(error) do
        error.kind in ["Elixir.ExUnit.AssertionError", "Elixir.ExUnit.CaseError"] or
          String.contains?(error.reason, "test") or
          String.contains?(error.reason, "ExUnit")
      end

      defp is_development_context?(context) do
        Map.get(context, "environment") == "development" or
          Map.get(context, "test_mode", false)
      end
    end

    test "ignores test-related errors", %{error: _error} do
      {:ok, stacktrace} = Faulty.Stacktrace.new([])

      {:ok, test_error} =
        Error.new("Elixir.ExUnit.AssertionError", "assertion failed", stacktrace)

      context = %{}

      assert DevelopmentIgnorer.ignore?(test_error, context) == true
    end

    test "ignores errors with test in reason", %{error: error} do
      test_error = %{error | reason: "This is a test error"}
      context = %{}

      assert DevelopmentIgnorer.ignore?(test_error, context) == true
    end

    test "ignores errors in development environment", %{error: error} do
      dev_context = %{"environment" => "development"}

      assert DevelopmentIgnorer.ignore?(error, dev_context) == true
    end

    test "ignores errors in test mode", %{error: error} do
      test_context = %{"test_mode" => true}

      assert DevelopmentIgnorer.ignore?(error, test_context) == true
    end

    test "does not ignore production errors", %{error: error} do
      prod_context = %{"environment" => "production"}

      assert DevelopmentIgnorer.ignore?(error, prod_context) == false
    end

    defmodule ThrottleIgnorer do
      @behaviour Faulty.Ignorer

      def ignore?(error, context) do
        # Simple throttling: ignore if we've seen this error recently
        throttle_key = "#{error.kind}:#{error.reason}"
        last_reported = Map.get(context, "last_error_#{throttle_key}")

        case last_reported do
          nil ->
            false

          timestamp when is_integer(timestamp) ->
            current_time = System.system_time(:second)
            # Ignore if reported in last 60 seconds
            current_time - timestamp < 60

          _ ->
            false
        end
      end
    end

    test "throttles duplicate errors", %{error: error} do
      current_time = System.system_time(:second)
      throttle_key = "Elixir.ArgumentError:production error"

      # First occurrence - should not be ignored
      context1 = %{}
      assert ThrottleIgnorer.ignore?(error, context1) == false

      # Second occurrence within throttle window - should be ignored
      context2 = %{"last_error_#{throttle_key}" => current_time - 30}
      assert ThrottleIgnorer.ignore?(error, context2) == true

      # Third occurrence outside throttle window - should not be ignored
      context3 = %{"last_error_#{throttle_key}" => current_time - 120}
      assert ThrottleIgnorer.ignore?(error, context3) == false
    end

    defmodule PatternIgnorer do
      @behaviour Faulty.Ignorer

      # Ignore specific error patterns that are known to be noisy
      @ignored_patterns [
        ~r/connection.*reset/i,
        ~r/timeout.*expired/i,
        ~r/network.*unreachable/i,
        ~r/temporary.*failure/i
      ]

      def ignore?(error, _context) do
        Enum.any?(@ignored_patterns, fn pattern ->
          String.match?(error.reason, pattern)
        end)
      end
    end

    test "ignores errors matching patterns", %{error: error} do
      connection_error = %{error | reason: "Connection reset by peer"}
      timeout_error = %{error | reason: "Request timeout expired"}
      network_error = %{error | reason: "Network unreachable"}
      temp_error = %{error | reason: "Temporary failure in name resolution"}
      normal_error = %{error | reason: "Invalid argument provided"}

      context = %{}

      assert PatternIgnorer.ignore?(connection_error, context) == true
      assert PatternIgnorer.ignore?(timeout_error, context) == true
      assert PatternIgnorer.ignore?(network_error, context) == true
      assert PatternIgnorer.ignore?(temp_error, context) == true
      assert PatternIgnorer.ignore?(normal_error, context) == false
    end

    defmodule UserIgnorer do
      @behaviour Faulty.Ignorer

      def ignore?(_error, context) do
        # Ignore errors from specific users or user roles
        user_id = Map.get(context, "user_id")
        user_role = Map.get(context, "user_role")

        # Test user IDs
        ignored_users = [123, 456]
        ignored_roles = ["test", "demo"]

        user_id in ignored_users or user_role in ignored_roles
      end
    end

    test "ignores errors from specific users", %{error: error} do
      test_user_context = %{"user_id" => 123}
      demo_user_context = %{"user_role" => "demo"}
      normal_user_context = %{"user_id" => 789, "user_role" => "user"}

      assert UserIgnorer.ignore?(error, test_user_context) == true
      assert UserIgnorer.ignore?(error, demo_user_context) == true
      assert UserIgnorer.ignore?(error, normal_user_context) == false
    end
  end
end
