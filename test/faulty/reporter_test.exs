defmodule Faulty.ReporterTest do
  use ExUnit.Case

  alias Faulty.Reporter

  @url "http://faulty.test/api/errors"

  setup context do
    Req.Test.set_req_test_to_shared(context)

    original_url = System.get_env("FAULTY_TOWER_URL")

    original_env =
      for key <- [:queue_size, :retry_interval, :retries, :req_options],
          do: {key, Application.get_env(:faulty, key)}

    System.put_env("FAULTY_TOWER_URL", @url)
    Application.put_env(:faulty, :retries, 0)
    Application.put_env(:faulty, :retry_interval, 10)
    Application.put_env(:faulty, :req_options, plug: {Req.Test, Reporter})

    on_exit(fn ->
      if original_url,
        do: System.put_env("FAULTY_TOWER_URL", original_url),
        else: System.delete_env("FAULTY_TOWER_URL")

      for {key, value} <- original_env do
        if value,
          do: Application.put_env(:faulty, key, value),
          else: Application.delete_env(:faulty, key)
      end

      :sys.replace_state(Reporter, fn state ->
        :ets.delete_all_objects(state.errors)
        if state.retry_timer, do: Process.cancel_timer(state.retry_timer)
        %{state | retry_timer: nil}
      end)
    end)

    :ok
  end

  describe "delivery" do
    test "posts a queued error to the configured url" do
      stub_status(fn _body -> 200 end)

      enqueue("boom")

      assert_receive {:request, _pid, body}
      assert body =~ "boom"
      wait_until_empty()
    end

    test "delivers errors in the order they were reported" do
      stub_status(fn _body -> 200 end)

      Enum.each(~w(first second third), &enqueue/1)

      assert_receive {:request, _, first}
      assert_receive {:request, _, second}
      assert_receive {:request, _, third}
      assert first =~ "first"
      assert second =~ "second"
      assert third =~ "third"
    end

    test "stays responsive while a delivery is in flight" do
      stub_status(fn _body -> block_until_released() end)

      enqueue("slow")
      assert_receive {:request, pid, _body}

      assert %{} = :sys.get_state(Reporter, 200)

      send(pid, :release)
      wait_until_empty()
    end

    test "drops the error without crashing when no url is configured" do
      System.delete_env("FAULTY_TOWER_URL")
      stub_status(fn _body -> 200 end)
      reporter = Process.whereis(Reporter)

      enqueue("nowhere")

      wait_until_empty()
      refute_received {:request, _, _}
      assert Process.whereis(Reporter) == reporter
    end
  end

  describe "failures" do
    test "a permanent 4xx is dropped and does not block later errors" do
      stub_status(fn body -> if body =~ "poison", do: 422, else: 200 end)

      enqueue("poison")
      enqueue("healthy")

      assert_receive {:request, _, poison}
      assert poison =~ "poison"
      assert_receive {:request, _, healthy}
      assert healthy =~ "healthy"
      wait_until_empty()
      refute_receive {:request, _, _}, 50
    end

    test "a 5xx is retried until it succeeds" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      stub_status(fn _body ->
        if Agent.get_and_update(counter, &{&1, &1 + 1}) == 0, do: 503, else: 200
      end)

      enqueue("flaky")

      assert_receive {:request, _, first}
      assert_receive {:request, _, second}
      assert first =~ "flaky"
      assert second =~ "flaky"
      wait_until_empty()
    end

    test "a 429 is retried until it succeeds" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      stub_status(fn _body ->
        if Agent.get_and_update(counter, &{&1, &1 + 1}) == 0, do: 429, else: 200
      end)

      enqueue("limited")

      assert_receive {:request, _, _}
      assert_receive {:request, _, _}
      wait_until_empty()
    end

    test "a network error is retried until it succeeds" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)
      test = self()

      Req.Test.stub(Reporter, fn conn ->
        if Agent.get_and_update(counter, &{&1, &1 + 1}) == 0 do
          Req.Test.transport_error(conn, :econnrefused)
        else
          send(test, {:request, self(), "delivered"})
          Plug.Conn.send_resp(conn, 200, "")
        end
      end)

      enqueue("offline")

      assert_receive {:request, _, "delivered"}, 1_000
      wait_until_empty()
    end

    test "does not hammer the server while backing off" do
      Application.put_env(:faulty, :retry_interval, 200)
      stub_status(fn _body -> 503 end)

      enqueue("down")
      assert_receive {:request, _, _}

      enqueue("also down")
      refute_receive {:request, _, _}, 100
    end
  end

  describe "queue bound" do
    test "drops new errors once the queue is full" do
      Application.put_env(:faulty, :queue_size, 2)
      stub_status(fn _body -> block_until_released() end)

      Enum.each(~w(one two three four five), &enqueue/1)
      :sys.get_state(Reporter)

      assert :ets.info(queue(), :size) == 2

      assert_receive {:request, first_pid, first}
      assert first =~ "one"
      send(first_pid, :release)

      assert_receive {:request, second_pid, second}
      assert second =~ "two"
      send(second_pid, :release)

      wait_until_empty()
      refute_receive {:request, _, _}, 50
    end
  end

  defp enqueue(reason) do
    {:ok, stacktrace} = Faulty.Stacktrace.new([])
    {:ok, error} = Faulty.Error.new("error", reason, stacktrace)
    Reporter.send(error, stacktrace, %{}, reason)
  end

  defp stub_status(fun) do
    test = self()

    Req.Test.stub(Reporter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test, {:request, self(), body})
      Plug.Conn.send_resp(conn, fun.(body), "")
    end)
  end

  defp block_until_released do
    receive do
      :release -> 200
    after
      2_000 -> 200
    end
  end

  defp queue, do: :sys.get_state(Reporter).errors

  defp wait_until_empty do
    Enum.reduce_while(1..200, nil, fn _, _ ->
      if :ets.info(queue(), :size) == 0 do
        {:halt, :ok}
      else
        Process.sleep(10)
        {:cont, nil}
      end
    end)

    assert :ets.info(queue(), :size) == 0
  end
end
