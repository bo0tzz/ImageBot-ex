defmodule ImageBot do
  @bot :image_bot

  use ExGram.Bot,
    name: @bot,
    setup_commands: true

  def bot(), do: @bot

  def handle({:text, _text, message}, context) do
    IO.inspect(message)
    answer(context, "Hello world!")
  end
end
