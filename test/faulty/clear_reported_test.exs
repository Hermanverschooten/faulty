defmodule Faulty.ClearReportedTest do
  use ExUnit.Case

  alias Faulty.Integrations.Oban, as: ObanIntegration
  alias Faulty.Integrations.Phoenix, as: PhoenixIntegration
  alias Faulty.Integrations.Plug, as: PlugIntegration
  alias Faulty.Integrations.Quantum, as: QuantumIntegration

  defmodule CapturingIgnorer do
    @behaviour Faulty.Ignorer

    def ignore?(error, _context) do
      send(self(), {:captured, error.reason})
      true
    end
  end

  setup do
    original_enabled = Application.get_env(:faulty, :enabled, true)
    original_ignorer = Application.get_env(:faulty, :ignorer)

    Application.put_env(:faulty, :enabled, true)
    Application.put_env(:faulty, :ignorer, CapturingIgnorer)

    on_exit(fn ->
      Application.put_env(:faulty, :enabled, original_enabled)
      Application.put_env(:faulty, :ignorer, original_ignorer)
    end)

    Faulty.clear_reported()
    :ok
  end

  describe "Faulty.clear_reported/0" do
    test "allows the process to report again after an error was reported" do
      report("first")
      report("second")

      assert_received {:captured, "first"}
      refute_received {:captured, "second"}

      Faulty.clear_reported()
      report("third")

      assert_received {:captured, "third"}
    end

    test "returns :ok when nothing was reported" do
      assert Faulty.clear_reported() == :ok
    end

    test "also allows the plug integration to report again" do
      conn = Plug.Test.conn(:get, "/")

      PlugIntegration.report_error(conn, %RuntimeError{message: "first"}, [])
      Faulty.clear_reported()
      PlugIntegration.report_error(conn, %RuntimeError{message: "second"}, [])

      assert_received {:captured, "first"}
      assert_received {:captured, "second"}
    end
  end

  describe "start of a unit of work clears the flags" do
    test "a plug request" do
      conn = Plug.Test.conn(:get, "/")

      PlugIntegration.report_error(conn, %RuntimeError{message: "first"}, [])
      PlugIntegration.set_context(conn)
      PlugIntegration.report_error(conn, %RuntimeError{message: "second"}, [])

      assert_received {:captured, "first"}
      assert_received {:captured, "second"}
    end

    test "a phoenix router dispatch" do
      conn = Plug.Test.conn(:get, "/")

      report("first")

      PhoenixIntegration.handle_event(
        [:phoenix, :router_dispatch, :start],
        %{},
        %{conn: conn},
        :no_config
      )

      report("second")

      assert_received {:captured, "first"}
      assert_received {:captured, "second"}
    end

    test "a live view mount" do
      report("first")

      PhoenixIntegration.handle_event(
        [:phoenix, :live_view, :mount, :start],
        %{},
        %{socket: %{view: __MODULE__}},
        :no_config
      )

      report("second")

      assert_received {:captured, "first"}
      assert_received {:captured, "second"}
    end

    test "a live view handle_params" do
      report("first")

      PhoenixIntegration.handle_event(
        [:phoenix, :live_view, :handle_params, :start],
        %{},
        %{uri: "http://localhost/", params: %{}},
        :no_config
      )

      report("second")

      assert_received {:captured, "first"}
      assert_received {:captured, "second"}
    end

    test "an oban job" do
      job = %{args: %{}, attempt: 1, id: 1, priority: 0, queue: "default", worker: "MyWorker"}

      report("first")

      ObanIntegration.handle_event([:oban, :job, :start], %{}, %{job: job}, :no_config)

      report("second")

      assert_received {:captured, "first"}
      assert_received {:captured, "second"}
    end

    test "a quantum job" do
      job = %{
        run_strategy: :local,
        overlap: true,
        timezone: :utc,
        name: "job",
        schedule: "* * * * *",
        task: {__MODULE__, :run, []}
      }

      report("first")

      QuantumIntegration.handle_event(
        [:quantum, :job, :start],
        %{},
        %{job: job, node: node(), scheduler: __MODULE__},
        :no_config
      )

      report("second")

      assert_received {:captured, "first"}
      assert_received {:captured, "second"}
    end
  end

  defp report(message) do
    Faulty.report(%RuntimeError{message: message}, [])
  end
end
