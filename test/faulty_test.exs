defmodule FaultyTest do
  use ExUnit.Case
  doctest Faulty

  test "greets the world" do
    assert Faulty.hello() == :world
  end
end
