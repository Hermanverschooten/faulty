ExUnit.start()

# Set up test environment configuration
Application.put_env(:faulty, :otp_app, :faulty)
Application.put_env(:faulty, :enabled, true)
