defmodule Mix.Tasks.Faulty.Install do
  use Igniter.Mix.Task

  @example "mix faulty.install --env TOWERURL"

  @shortdoc "Install Faulty for error tracking"
  @moduledoc """
  #{@shortdoc}

  This will inject the necessary dependencies and update your config to start
  tracking errors with Faulty.

  ## Example

  ```bash
  #{@example}
  ```

  ## Options

  * `--env  - The environment variable containing the faulty tower error tracking site, default: FAULTY_TOWER_URL.
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      # Groups allow for overlapping arguments for tasks by the same author
      # See the generators guide for more.
      group: :faulty,
      # dependencies to add
      adds_deps: [{:faulty, github: "Hermanverschooten/faulty"}],
      # dependencies to add and call their associated installers, if they exist
      # installs: [],
      # An example invocation
      example: @example,
      # A list of environments that this should be installed in.
      # only: nil,
      # a list of positional arguments, i.e `[:file]`
      # positional: [],
      # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
      # This ensures your option schema includes options from nested tasks
      # composes: [],
      # `OptionParser` schema
      schema: [env: :string]
      # Default values for the options in the `schema`
      # defaults: [],
      # CLI aliases
      # aliases: [],
      # A list of options in the schema that are required
      # required: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app = Igniter.Project.Application.app_name(igniter)

    igniter =
      if env = Keyword.get(igniter.args.options, :env) do
        igniter
        |> Igniter.Project.Config.configure(
          "config.exs",
          :faulty,
          [:env],
          env
        )
      else
        igniter
      end

    igniter
    |> Igniter.Project.Config.configure(
      "dev.exs",
      :faulty,
      [:enabled],
      false
    )
    |> Igniter.Project.Config.configure(
      "dev.exs",
      :faulty,
      [:connect_options],
      transport_opts: [verify: :verify_none]
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :faulty,
      [:otp_app],
      app
    )
    |> Igniter.Project.Config.configure(
      "test.exs",
      :faulty,
      [:enabled],
      false
    )
    |> Igniter.Project.Config.configure(
      "prod.exs",
      :faulty,
      [:enabled],
      true
    )
  end
end
