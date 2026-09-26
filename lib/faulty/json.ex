defmodule Faulty.Json do
  @moduledoc false

  @candidates [JSON, Jason]

  @spec library() :: module() | nil
  def library do
    Application.get_env(:faulty, :json_library) || Enum.find(@candidates, &Code.ensure_loaded?/1)
  end

  @spec encode!(term()) :: binary()
  def encode!(term), do: IO.iodata_to_binary(library().encode!(term))

  @spec validate!(module() | nil) :: :ok
  def validate!(library \\ library())

  def validate!(nil) do
    raise ArgumentError, """
    Faulty could not find a JSON library.

    Elixir 1.18 and later include JSON. On an older Elixir, add :jason to your dependencies
    and set the :json_library option:

        config :faulty, json_library: Jason
    """
  end

  def validate!(library) do
    cond do
      not Code.ensure_loaded?(library) ->
        raise ArgumentError,
              "the :json_library #{inspect(library)} could not be loaded, " <>
                "check that it is one of your dependencies"

      not function_exported?(library, :encode!, 1) ->
        raise ArgumentError,
              "the :json_library #{inspect(library)} does not export encode!/1"

      true ->
        :ok
    end
  end
end
