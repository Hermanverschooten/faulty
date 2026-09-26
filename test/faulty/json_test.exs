defmodule Faulty.JsonTest do
  use ExUnit.Case

  alias Faulty.Json

  defmodule NoEncoder do
  end

  setup do
    original = Application.get_env(:faulty, :json_library)

    on_exit(fn ->
      if original,
        do: Application.put_env(:faulty, :json_library, original),
        else: Application.delete_env(:faulty, :json_library)
    end)

    Application.delete_env(:faulty, :json_library)
    :ok
  end

  describe "library/0" do
    test "defaults to the built-in JSON module" do
      assert Json.library() == JSON
    end

    test "uses the configured library" do
      Application.put_env(:faulty, :json_library, Jason)

      assert Json.library() == Jason
    end
  end

  describe "encode!/1" do
    test "encodes with the default library" do
      assert %{"a" => 1} == %{"a" => 1} |> Json.encode!() |> JSON.decode!()
    end

    test "encodes with the configured library" do
      Application.put_env(:faulty, :json_library, Jason)

      assert %{"a" => 1} == %{"a" => 1} |> Json.encode!() |> Jason.decode!()
    end

    test "returns a binary" do
      assert is_binary(Json.encode!(%{"a" => 1}))
    end
  end

  describe "validate!/1" do
    test "accepts the default library" do
      assert Json.validate!() == :ok
    end

    test "accepts a library that exports encode!/1" do
      assert Json.validate!(Jason) == :ok
    end

    test "raises when no library is available" do
      error = assert_raise ArgumentError, fn -> Json.validate!(nil) end

      assert error.message =~ "JSON library"
      assert error.message =~ ":jason"
      assert error.message =~ ":json_library"
    end

    test "raises when the configured module cannot be loaded" do
      error = assert_raise ArgumentError, fn -> Json.validate!(NoSuchJsonLibrary) end

      assert error.message =~ "NoSuchJsonLibrary"
      assert error.message =~ ":json_library"
    end

    test "raises when the module does not export encode!/1" do
      error = assert_raise ArgumentError, fn -> Json.validate!(NoEncoder) end

      assert error.message =~ "encode!/1"
      assert error.message =~ "NoEncoder"
    end
  end
end
