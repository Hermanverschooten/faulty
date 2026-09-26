defmodule Faulty.HttpTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Faulty.Http

  setup do
    original =
      for key <- [:retries, :req_options, :connect_options],
          do: {key, Application.get_env(:faulty, key)}

    on_exit(fn ->
      for {key, value} <- original do
        if value,
          do: Application.put_env(:faulty, key, value),
          else: Application.delete_env(:faulty, key)
      end
    end)

    :ok
  end

  describe "the httpc profile" do
    test "is started with the application under its own name" do
      assert is_pid(Process.whereis(:httpc_faulty))
    end

    test "can be started again without an error" do
      assert :ok = Http.start_profile()
    end
  end

  describe "warn_about_ignored_config/0" do
    test "is silent with the default configuration" do
      assert capture_log([level: :warning], fn -> Http.warn_about_ignored_config() end) == ""
    end

    test "warns that :retries is no longer used" do
      Application.put_env(:faulty, :retries, 5)

      log = capture_log([level: :warning], fn -> Http.warn_about_ignored_config() end)

      assert log =~ ":retries"
    end

    test "warns that :req_options is no longer used" do
      Application.put_env(:faulty, :req_options, retry: false)

      log = capture_log([level: :warning], fn -> Http.warn_about_ignored_config() end)

      assert log =~ ":req_options"
    end

    test "warns about connect_options keys that are not supported" do
      Application.put_env(:faulty, :connect_options,
        transport_opts: [verify: :verify_none],
        protocols: [:http2],
        hostname: "example.com"
      )

      log = capture_log([level: :warning], fn -> Http.warn_about_ignored_config() end)

      assert log =~ "ignoring the unsupported :connect_options [:protocols, :hostname]"
    end
  end
end
