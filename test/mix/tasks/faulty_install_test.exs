defmodule Mix.Tasks.Faulty.InstallTest do
  use ExUnit.Case

  import Igniter.Test

  alias Mix.Tasks.Faulty.Install

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
  end

  describe "the installer" do
    test "does not add jason on an Elixir that has the JSON module" do
      igniter =
        test_project()
        |> Igniter.compose_task("faulty.install", [])

      refute content(igniter, "mix.exs") =~ "jason"
      config = content(igniter, "config/config.exs")

      assert config =~ "otp_app: :test"
      refute config =~ "json_library"
    end
  end

  defp content(igniter, path),
    do: igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
end
