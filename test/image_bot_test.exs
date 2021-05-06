defmodule ImageBotTest do
  use ExUnit.Case
  doctest ImageBot

  test "greets the world" do
    assert ImageBot.hello() == :world
  end
end
