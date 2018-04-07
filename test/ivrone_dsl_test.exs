defmodule IvroneDslTest do
  use ExUnit.Case
  doctest IvroneDsl

  test "greets the world" do
    assert IvroneDsl.hello() == :world
  end
end
