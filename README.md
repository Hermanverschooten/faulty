# Faulty

Error tracking for your application.

<a title="Latest release" href="https://hex.pm/packages/faulty"><img src="https://img.shields.io/hexpm/v/faulty.svg" alt="Latest release" /></a>
<a title="View documentation" href="https://hexdocs.pm/faulty"><img src="https://img.shields.io/badge/hex.pm-docs-blue.svg" alt="View documentation" /></a>



## Installation

Add `faulty` to your `mix.exs` file, then `mix deps.get` it.

```elixir
def deps do
  [
    {:faulty, "~> 0.2"}
  ]
end
```

or you can also use `igniter` to add/install `Faulty`.

```elixir
mix igniter.install faulty`
```

## Configuration

Add the following to your `config/config.exs` file:

```elixir
config :faulty,
    otp_app: :your_app,
    enabled: true,
    queue_size: 1000,
    scrub_pii: true,
    retry_interval: :timer.minutes(1),
    json_library: JSON,
    connect_options: [...]
```

The `:otp_app` option specifies your application, this allows `FaultyTower` to filter only your app's stack traces.

The `:env` option should be filled in with the name of the environment variable that contains the link to your FaultyTower instance, default is FAULTY_TOWER_URL.

The `:enabled` option if not given, will default to `true`. You probable want to turn this off for your test environment.

Errors are queued and sent one at a time, in the order they were reported, without blocking your application. If `FaultyTower` cannot be reached, or answers with a `408`, `429` or `5xx` status, the error stays at the head of the queue and is tried again after `:retry_interval` milliseconds, defaults to one minute. Any other response, such as a `422`, means the error will never be accepted and it is dropped, so it can't hold up the errors queued behind it.

The `:queue_size` option limits how many errors wait to be sent, defaults to 1000. Once the queue is full new errors are dropped until there is room again, so an outage of `FaultyTower` can't make your application use more and more memory.

The `:scrub_pii` option, defaults to `true`, replaces the value of every sensitive key in the error context with `"[FILTERED]"` before it is sent. This covers request headers and params, Oban job args, LiveView event params and anything you add with `Faulty.set_context/1`. Keys such as `password`, `token`, `secret`, `authorization`, `x-api-key` and `cookie` are matched, ignoring case and separators, see `Faulty.Scrubber` for the full list. Only keys are checked, error messages are not touched. Set it to `false` to turn it off, your own `Faulty.Filter` runs afterwards either way.

The `:json_library` option is the module used to encode errors as JSON, defaults to the `JSON` module that is part of Elixir 1.18+. Any module that exports `encode!/1` works, such as `Jason`. On Elixir 1.17 there is no `JSON` module, add `{:jason, "~> 1.0"}` to your dependencies and set `json_library: Jason`, `mix faulty.install` does this for you. Faulty checks the library when it starts. Values in the error context must be encodable by it.

Errors are sent with Erlang's built-in `:httpc`, so `Faulty` has no HTTP client dependency. The certificate of your `FaultyTower` is verified against your system's CA certificates.

The `:connect_options` tune the connection, these keys are supported:

* `:transport_opts` are `:ssl` options, merged over the secure defaults. For a `FaultyTower` with a self-signed certificate, for instance in development, use `transport_opts: [verify: :verify_none]`, or trust your own CA with `transport_opts: [cacertfile: "/path/to/ca.pem"]`.
* `:timeout` is the connect timeout in milliseconds, defaults to 30 seconds.
* `:proxy` is `{:http, "proxy.example.com", 3128, []}`, it is read when `Faulty` starts.

The `:receive_timeout` option limits how long a single request may take in milliseconds, defaults to 15 seconds.

## Error tracking

Once configured `Faulty` is ready to start tracking your errors. It automatically starts with your application and tracks errors in your Phoenix controllers, LiveViews en Oban jobs.
Checkout the `Faulty.Integrations.Phoenix` and `Faulty.Integrations.Oban` for more detailed information.

If your application uses Plug but not Phoenix, you will need to add the relevant integration in your `Plug.Builder` or `Plug.Router` module.

```elixir
defmodule MyApp.Router do
  use Plug.Router
  use Faulty.Integrations.Plug

  # Your code here
end
```

This is also required if you want to track errors that happen in your Phoenix endpoint, before the Phoenix router starts handling the request. Keep in mind that this won't be needed in most cases as endpoint errors are infrequent.

```elixir
defmodule MyApp.Endpoint do
  use Phoenix.Endpoint
  use Faulty.Integrations.Plug

  # Your code here
end
```

You can learn more about this in the `Faulty.Integrations.Plug` module documentation.

## Error context

The default integrations include some additional context when tracking errors. You can take a look at the relevant integration modules to see what is being tracked out of the box.

In certain cases, you may want to include some additional information when tracking errors. For example it may be useful to track the user ID that was using the application when an error happened. Fortunately, Faulty allows you to enrich the default context with custom information.

The `Faulty.set_context/1` function stores the given context in the current process so any errors that occur in that process (for example, a Phoenix request or an Oban job) will include this given context along with the default integration context.

There are some requirements on the type of data that can be included in the context, so we recommend taking a look at `Faulty.set_context/1` documentation

```elixir
Faulty.set_context(%{"user_id" =>  conn.assigns.current_user.id})
```

You may also want to sanitize or filter out some information from the context before saving it. To do that you can take a look at the `Faulty.Filter` behaviour.

## Manual error tracking

If you want to report custom errors that fall outside the default integration scope, you may use `Faulty.report/2`. This allows you to report an exception yourself:

```elixir
try do
  # your code
catch
  e ->
    Faulty.report(e, __STACKTRACE__)
end
```

You can also use `Faulty.report/3` and set some custom context that will be included along with the reported error.

## Ignoring errors

Faulty tracks every error by default. In certain cases some errors may be expected or just not interesting to track.
Faulty provides functionality that allows you to ignore errors based on their attributes and context.

Take a look at the `Faulty.Ignorer` behaviour for more information about how to implement your own ignorer.

## Faulty Tower

[Faulty Tower](https://github.com/Hermanverschooten/faulty_tower) is the accompanying website that hosts the error database.
