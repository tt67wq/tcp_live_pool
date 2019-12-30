defmodule LocalTest do
  use ExUnit.Case
  doctest Local

  test "greets the world" do
    assert Local.hello() == :world
  end
end
