defmodule Faulty.Web do
  @moduledoc """
  Faulty includes a dashboard to view and inspect errors that occurred
  on your application and are already stored in the database.

  In order to use it, you need to add the following to your Phoenix's
  `router.ex` file:

  ```elixir
  defmodule YourAppWeb.Router do
    use Phoenix.Router
    use Faulty.Web, :router

    ...

    faulty_dashboard "/errors"
  end
  ```

  This will add the routes needed for Faulty's dashboard to work.

  ## Security considerations

  Errors may contain sensitive information, like IP addresses, users information
  or even passwords sent on forms!

  Securing your dashboard is an important part of integrating Faulty on
  your project.

  In order to do so, we recommend implementing your own security mechanisms in
  the form of a mount hook and pass it to the `faulty_dashboard` macro
  using the `on_mount` option.

  You can find more details on
  `Faulty.Web.Router.faulty_dashboard/2`.

  ### Static assets

  Static assets (CSS and JS) are inlined during the compilation. If you have
  a [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
  be sure to allow inline styles and scripts.

  To do this, ensure that your `style-src` and `script-src` policies include the
  `unsafe-inline` value.

  ## LiveView socket options

  By default the library expects you to have your LiveView socket at `/live` and
  using `websocket` transport.

  If that's not the case, you can configure it adding the following
  configuration to your app's config files:

  ```elixir
  config :faulty,
    socket: [
      path: "/my-custom-socket-path"
      transport: :longpoll # (accepted values are :longpoll or :websocket)
    ]
  ```
  """

  @doc false
  def html do
    quote do
      import Phoenix.Controller, only: [get_csrf_token: 0]

      unquote(html_helpers())
    end
  end

  @doc false
  def live_view do
    quote do
      use Phoenix.LiveView, layout: {Faulty.Web.Layouts, :live}

      unquote(html_helpers())
    end
  end

  @doc false
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @doc false
  def router do
    quote do
      import Faulty.Web.Router
    end
  end

  defp html_helpers do
    quote do
      use Phoenix.Component

      import Phoenix.HTML
      import Phoenix.LiveView.Helpers

      import Faulty.Web.CoreComponents
      import Faulty.Web.Helpers
      import Faulty.Web.Router.Routes

      alias Phoenix.LiveView.JS
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
