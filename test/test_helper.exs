ExUnit.start()

# Set up test environment configuration
Application.put_env(:faulty, :otp_app, :faulty)
Application.put_env(:faulty, :enabled, true)

warmup = Faulty.TestServer.start(fn _request -> 200 end)
{:ok, 200} = Faulty.Http.post(warmup.url, "{}")
