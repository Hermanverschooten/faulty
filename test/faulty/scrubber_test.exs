defmodule Faulty.ScrubberTest do
  use ExUnit.Case

  alias Faulty.Scrubber

  doctest Faulty.Scrubber

  describe "scrub/1" do
    test "redacts the value under a sensitive key" do
      assert Scrubber.scrub(%{"password" => "hunter2", "name" => "Herman"}) ==
               %{"password" => "[FILTERED]", "name" => "Herman"}
    end

    test "works with atom keys" do
      assert Scrubber.scrub(%{password: "hunter2", name: "Herman"}) ==
               %{password: "[FILTERED]", name: "Herman"}
    end

    test "ignores case and separators in the key" do
      context = %{
        "Authorization" => "Bearer abc",
        "x-api-key" => "abc",
        "apiKey" => "abc",
        "credit_card_number" => "4111 1111 1111 1111",
        "CSRF-Token" => "abc",
        "set-cookie" => "session=abc"
      }

      assert Scrubber.scrub(context) |> Map.values() |> Enum.uniq() == ["[FILTERED]"]
    end

    test "redacts the whole value whatever its type" do
      assert Scrubber.scrub(%{"token" => %{"a" => 1}, "secret" => [1, 2], "pwd" => 12}) ==
               %{"token" => "[FILTERED]", "secret" => "[FILTERED]", "pwd" => "[FILTERED]"}
    end

    test "recurses into nested maps and lists" do
      context = %{
        "request.params" => %{"user" => %{"email" => "a@b.c", "password" => "hunter2"}},
        "job.args" => [%{"api_key" => "abc"}, %{"id" => 1}]
      }

      assert Scrubber.scrub(context) == %{
               "request.params" => %{"user" => %{"email" => "a@b.c", "password" => "[FILTERED]"}},
               "job.args" => [%{"api_key" => "[FILTERED]"}, %{"id" => 1}]
             }
    end

    test "leaves nil values, unrelated keys and non-map values alone" do
      assert Scrubber.scrub(%{"password" => nil, "username" => "herman", "author" => "x"}) ==
               %{"password" => nil, "username" => "herman", "author" => "x"}

      assert Scrubber.scrub("plain") == "plain"
      assert Scrubber.scrub(42) == 42
    end

    test "leaves structs opaque" do
      now = DateTime.utc_now()

      assert Scrubber.scrub(%{"at" => now}) == %{"at" => now}
    end
  end

  describe "Faulty.report/3" do
    defmodule CapturingFilter do
      @behaviour Faulty.Filter

      def sanitize(context) do
        send(self(), {:filtered, context})
        context
      end
    end

    setup do
      original_filter = Application.get_env(:faulty, :filter)
      original_scrub = Application.get_env(:faulty, :scrub_pii)
      original_enabled = Application.get_env(:faulty, :enabled, true)

      Application.put_env(:faulty, :enabled, true)
      Application.put_env(:faulty, :filter, CapturingFilter)
      Application.delete_env(:faulty, :scrub_pii)
      Faulty.clear_reported()

      on_exit(fn ->
        Application.put_env(:faulty, :enabled, original_enabled)
        Application.put_env(:faulty, :filter, original_filter)

        if original_scrub,
          do: Application.put_env(:faulty, :scrub_pii, original_scrub),
          else: Application.delete_env(:faulty, :scrub_pii)

        Faulty.clear_reported()
        Process.delete(:faulty_context)
      end)

      :ok
    end

    test "scrubs the context before the filter sees it" do
      Faulty.report(%RuntimeError{message: "boom"}, [], %{"password" => "hunter2", "id" => 1})

      assert_received {:filtered, %{"password" => "[FILTERED]", "id" => 1}}
    end

    test "scrubs the process context too" do
      Faulty.set_context(%{"request.headers" => %{"authorization" => "Bearer abc"}})
      Faulty.report(%RuntimeError{message: "boom"}, [])

      assert_received {:filtered, %{"request.headers" => %{"authorization" => "[FILTERED]"}}}
    end

    test "leaves the context alone when scrub_pii is false" do
      Application.put_env(:faulty, :scrub_pii, false)

      Faulty.report(%RuntimeError{message: "boom"}, [], %{"password" => "hunter2"})

      assert_received {:filtered, %{"password" => "hunter2"}}
    end
  end
end
