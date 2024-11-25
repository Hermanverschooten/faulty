# Faulty

Error tracking for your application.

<a title="GitHub CI" href="https://github.com/Hermanverschooten/error-tracker/actions"><img src="https://github.com/Hermanverschooten/error-tracker/workflows/CI/badge.svg" alt="GitHub CI" /></a>
<a title="Latest release" href="https://hex.pm/packages/faulty"><img src="https://img.shields.io/hexpm/v/faulty.svg" alt="Latest release" /></a>
<a title="View documentation" href="https://hexdocs.pm/faulty"><img src="https://img.shields.io/badge/hex.pm-docs-blue.svg" alt="View documentation" /></a>



## Installation

Add `faulty` to your `mix.exs` file, then `mix deps.get` it.

```elixir
def deps do
  [
    {:faulty, "~> 0.1.0"}
  ]
end
```

or you can also use `igniter` to add/install `Faulty`.

`mix igniter.install faulty@github:Hermanverschooten/faulty`

## Configuration

Add the following to your `config/config.exs` file:

```elixir
config :faulty,
    otp_app: :your_app,
    enabled: true,
    retries: 5,
    connect_options: [...]
```

The `:otp_app` option specifies your application, this allows `FaultyTower` to filter only your app's stack traces.

The `:env` should be filled in with the name of the environment variable that contains the link to your FaultyTower instance, default is FAULTY_TOWER_URL.

The `:enabled` option if not given, will default to `true`. You probable want to turn this off for your test environment.

The `:retries` option is used to tell `Req` how many times to retry sending the error to `FaultyTower`, defaults to 5. If it hasn't succeeded by then the error will be dropped.

The `:connect_options` are passed through to `Req`.

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
