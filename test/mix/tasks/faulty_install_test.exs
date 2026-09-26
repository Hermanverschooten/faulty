defmodule Mix.Tasks.Faulty.InstallTest do
  use ExUnit.Case

  import Igniter.Test

  alias Mix.Tasks.Faulty.Install

  describe "configuration" do
    test "sets the otp_app to the app of the project" do
      igniter = install()

      assert content(igniter, "config/config.exs") =~ "otp_app: :test"
    end

    test "disables Faulty in dev and lets it talk to a local tower without a verified certificate" do
      dev = install() |> content("config/dev.exs")

      assert dev =~ "enabled: false"
      assert dev =~ "connect_options: [transport_opts: [verify: :verify_none]]"
    end

    test "disables Faulty in test" do
      assert install() |> content("config/test.exs") =~ "enabled: false"
    end

    test "enables Faulty in prod" do
      assert install() |> content("config/prod.exs") =~ "enabled: true"
    end

    test "leaves the url environment variable at its default" do
      refute install() |> content("config/config.exs") =~ "env:"
    end

    test "sets the url environment variable with --env-var" do
      igniter = install(test_project(), ["--env-var", "TOWERURL"])

      assert content(igniter, "config/config.exs") =~ ~s(env: "TOWERURL")
    end

    test "accepts the option as it is spelled in the documentation" do
      [_mix, _task | args] = String.split(Install.Docs.example())

      igniter = install(test_project(), args)

      assert content(igniter, "config/config.exs") =~ ~s(env: "TOWERURL")
    end

    test "does not write the options that have good defaults" do
      igniter = install()

      configs =
        for path <- ~w(config/config.exs config/dev.exs config/test.exs config/prod.exs),
            do: content(igniter, path)

      for option <-
            ~w(queue_size retry_interval receive_timeout scrub_pii json_library retries req_options) do
        refute Enum.any?(configs, &(&1 =~ option)), "#{option} should not be written"
      end
    end
  end

  describe "an existing project" do
    test "keeps the configuration that is already there" do
      igniter =
        test_project(
          files: %{
            "config/config.exs" => """
            import Config

            config :other, key: :value
            """
          }
        )
        |> install()

      config = content(igniter, "config/config.exs")

      assert config =~ "config :other, key: :value"
      assert config =~ "otp_app: :test"
    end

    test "updates an existing faulty configuration instead of adding a second one" do
      igniter =
        test_project(
          files: %{
            "config/dev.exs" => """
            import Config

            config :faulty, enabled: true
            """
          }
        )
        |> install()

      dev = content(igniter, "config/dev.exs")

      assert dev =~ "enabled: false"
      refute dev =~ "enabled: true"
      assert length(String.split(dev, "config :faulty")) == 2
    end

    test "changes nothing when it is run a second time" do
      test_project()
      |> install()
      |> apply_igniter!()
      |> install()
      |> assert_unchanged()
    end

    test "installs into a phoenix project" do
      igniter = install(phx_test_project())

      assert content(igniter, "config/config.exs") =~ "otp_app: :test"
      assert content(igniter, "config/prod.exs") =~ "enabled: true"
    end
  end

  describe "info/2" do
    test "belongs to the faulty group and takes the env-var option" do
      info = Install.info([], nil)

      assert info.group == :faulty
      assert Keyword.fetch!(info.schema, :env_var) == :string
    end
  end

  describe "add_json_library/2" do
    test "leaves the project alone when the JSON module is available" do
      test_project()
      |> Install.add_json_library(true)
      |> assert_unchanged()
    end

    test "adds jason and the json_library option when there is no JSON module" do
      igniter =
        test_project()
        |> Install.add_json_library(false)
        |> assert_has_patch("mix.exs", """
        + | {:jason, "~> 1.0"}
        """)

      assert content(igniter, "config/config.exs") =~ "config :faulty, json_library: Jason"
    end

    test "does not add jason on an Elixir that has the JSON module" do
      igniter = install()

      refute content(igniter, "mix.exs") =~ "jason"
      refute content(igniter, "config/config.exs") =~ "json_library"
    end
  end

  defp install(igniter \\ test_project(), args \\ []) do
    Igniter.compose_task(igniter, "faulty.install", args)
  end

  defp content(igniter, path),
    do: igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
end
