defmodule Faulty.ReporterTest do
  use ExUnit.Case

  alias Faulty.Reporter
  alias Faulty.TestServer

  setup do
    original_url = System.get_env("FAULTY_TOWER_URL")

    original_env =
      for key <- [:queue_size, :retry_interval, :connect_options, :receive_timeout],
          do: {key, Application.get_env(:faulty, key)}

    Application.put_env(:faulty, :retry_interval, 10)

    on_exit(fn ->
      reset_reporter()

      if original_url,
        do: System.put_env("FAULTY_TOWER_URL", original_url),
        else: System.delete_env("FAULTY_TOWER_URL")

      for {key, value} <- original_env do
        if value,
          do: Application.put_env(:faulty, key, value),
          else: Application.delete_env(:faulty, key)
      end

      restart_http_profile()
    end)

    :ok
  end

  describe "delivery" do
    test "posts a queued error to the configured url" do
      serve(fn _body -> 200 end)

      enqueue("boom")

      assert_receive {:request, _pid, body}
      assert body =~ "boom"
      wait_until_empty()
    end

    test "posts json" do
      serve(fn _body -> 200 end)

      enqueue("boom")

      assert_receive {:meta, %{method: "POST", headers: %{"content-type" => content_type}}}
      assert content_type =~ "application/json"
      wait_until_empty()
    end

    test "delivers errors in the order they were reported" do
      serve(fn _body -> 200 end)

      Enum.each(~w(first second third), &enqueue/1)

      assert_receive {:request, _, first}
      assert_receive {:request, _, second}
      assert_receive {:request, _, third}
      assert first =~ "first"
      assert second =~ "second"
      assert third =~ "third"
    end

    test "stays responsive while a delivery is in flight" do
      serve(fn _body -> block_until_released() end)

      enqueue("slow")
      assert_receive {:request, pid, _body}

      assert %{} = :sys.get_state(Reporter, 200)

      send(pid, :release)
      wait_until_empty()
    end

    test "drops the error without crashing when no url is configured" do
      serve(fn _body -> 200 end)
      System.delete_env("FAULTY_TOWER_URL")
      reporter = Process.whereis(Reporter)

      enqueue("nowhere")

      wait_until_empty()
      refute_received {:request, _, _}
      assert Process.whereis(Reporter) == reporter
    end
  end

  describe "failures" do
    test "a permanent 4xx is dropped and does not block later errors" do
      serve(fn body -> if body =~ "poison", do: 422, else: 200 end)

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

      serve(fn _body ->
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

      serve(fn _body ->
        if Agent.get_and_update(counter, &{&1, &1 + 1}) == 0, do: 429, else: 200
      end)

      enqueue("limited")

      assert_receive {:request, _, _}
      assert_receive {:request, _, _}
      wait_until_empty()
    end

    test "a network error is retried until it succeeds" do
      System.put_env("FAULTY_TOWER_URL", TestServer.dead_url())

      enqueue("offline")
      Process.sleep(50)
      assert :ets.info(queue(), :size) == 1

      serve(fn _body -> 200 end)

      assert_receive {:request, _, body}, 1_000
      assert body =~ "offline"
      wait_until_empty()
    end

    test "does not hammer the server while backing off" do
      Application.put_env(:faulty, :retry_interval, 200)
      serve(fn _body -> 503 end)

      enqueue("down")
      assert_receive {:request, _, _}

      enqueue("also down")
      refute_receive {:request, _, _}, 100
    end
  end

  describe "connection options" do
    @describetag :capture_log

    test "does not deliver to a server whose certificate cannot be verified" do
      serve(fn _body -> 200 end, tls: self_signed_tls())

      enqueue("insecure")
      Process.sleep(200)

      refute_received {:request, _, _}
      assert :ets.info(queue(), :size) == 1
    end

    test "transport_opts are used as the tls options" do
      serve(fn _body -> 200 end, tls: self_signed_tls())
      Application.put_env(:faulty, :connect_options, transport_opts: [verify: :verify_none])

      enqueue("trusted")

      assert_receive {:request, _, body}, 1_000
      assert body =~ "trusted"
      wait_until_empty()
    end

    test "gives up on a request that takes longer than receive_timeout and retries it" do
      Application.put_env(:faulty, :receive_timeout, 50)
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      serve(fn _body ->
        if Agent.get_and_update(counter, &{&1, &1 + 1}) == 0, do: Process.sleep(400)
        200
      end)

      enqueue("slow")

      assert_receive {:request, _, _}, 1_000
      assert_receive {:request, _, _}, 1_000
      wait_until_empty()
    end

    test "sends the request through a configured proxy" do
      parent = self()

      proxy =
        TestServer.start(fn request ->
          send(parent, {:proxied, request.host, request.method})
          200
        end)

      System.put_env("FAULTY_TOWER_URL", "http://faulty.invalid/api/errors")
      Application.put_env(:faulty, :connect_options, proxy: {:http, "127.0.0.1", proxy.port, []})
      restart_http_profile()

      enqueue("proxied")

      assert_receive {:proxied, "faulty.invalid", "POST"}, 1_000
      wait_until_empty()
    end

    test "leaves the default httpc profile alone" do
      serve(fn _body -> 200 end)
      Application.put_env(:faulty, :connect_options, proxy: {:http, "127.0.0.1", 1, []})
      restart_http_profile()

      enqueue("isolated")
      Process.sleep(100)

      assert {:ok, [proxy: {:undefined, []}]} = :httpc.get_options([:proxy], :default)
    end
  end

  describe "queue bound" do
    test "drops new errors once the queue is full" do
      Application.put_env(:faulty, :queue_size, 2)
      serve(fn _body -> block_until_released() end)

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

  defp serve(fun, opts \\ []) do
    test = self()

    server =
      TestServer.start(
        fn request ->
          send(test, {:request, self(), request.body})
          send(test, {:meta, request})
          fun.(request.body)
        end,
        opts
      )

    System.put_env("FAULTY_TOWER_URL", server.url)
    server
  end

  defp self_signed_tls do
    chain = fn ->
      %{
        root: [key: :public_key.generate_key({:rsa, 2048, 65537})],
        intermediates: [],
        peer: [key: :public_key.generate_key({:rsa, 2048, 65537})]
      }
    end

    %{server_config: server_config} =
      :public_key.pkix_test_data(%{server_chain: chain.(), client_chain: chain.()})

    server_config
  end

  defp block_until_released do
    receive do
      :release -> 200
    after
      2_000 -> 200
    end
  end

  defp queue, do: :sys.get_state(Reporter).errors

  defp reset_reporter do
    clear = fn ->
      :sys.replace_state(Reporter, fn state ->
        :ets.delete_all_objects(state.errors)
        if state.retry_timer, do: Process.cancel_timer(state.retry_timer)
        %{state | retry_timer: nil}
      end)
    end

    clear.()
    wait_until_idle()
    clear.()
  end

  defp restart_http_profile do
    Faulty.Http.stop_profile()
    Faulty.Http.start_profile()
  end

  defp wait_until_idle do
    Enum.reduce_while(1..200, nil, fn _, _ ->
      if :sys.get_state(Reporter).delivering == nil do
        {:halt, :ok}
      else
        Process.sleep(10)
        {:cont, nil}
      end
    end)
  end

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
