defmodule Es3Test do
  use ExUnit.Case
  doctest Es3

  test "greets the world" do
    assert Es3.hello() == :world
  end
end
