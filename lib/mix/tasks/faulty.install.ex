defmodule Mix.Tasks.Faulty.Install.Docs do
  @moduledoc false

  def short_doc do
    "This will inject the necessary dependencies and update your config to start tracking errors with Faulty."
  end

  def example do
    "mix faulty.install --env_var TOWERURL"
  end

  def long_doc do
    """
    #{short_doc()}

    ## Example

    ```bash
    #{example()}
    ```

    ## Options

    * `--env_var` - The environment variable that holds your faulty tower url, defaults to: FAULTY_TOWER_URL
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Faulty.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        # Groups allow for overlapping arguments for tasks by the same author
        # See the generators guide for more.
        group: :faulty,
        # *other* dependencies to add
        # i.e `{:foo, "~> 2.0"}`
        adds_deps: [],
        # *other* dependencies to add and call their associated installers, if they exist
        # i.e `{:foo, "~> 2.0"}`
        installs: [],
        # An example invocation
        example: __MODULE__.Docs.example(),
        # A list of environments that this should be installed in.
        only: nil,
        # a list of positional arguments, i.e `[:file]`
        positional: [],
        # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
        # This ensures your option schema includes options from nested tasks
        composes: [],
        # `OptionParser` schema
        schema: [env_var: :string],
        # Default values for the options in the `schema`
        defaults: [],
        # CLI aliases
        aliases: [],
        # A list of options in the schema that are required
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      app = Igniter.Project.Application.app_name(igniter)

      igniter =
        if env = Keyword.get(igniter.args.options, :env_var) do
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
else
  defmodule Mix.Tasks.Faulty.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'faulty.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
