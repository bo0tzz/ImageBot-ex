defmodule ImageBot do
  @bot :image_bot

  use ExGram.Bot,
    name: @bot,
    setup_commands: true

  def bot(), do: @bot

  def handle({:inline_query, %{query: query} = msg}, context) do
    case String.trim(query) do
      "" -> nil
      _ -> handle_inline_query(msg, context)
    end
  end

  defp handle_inline_query(%{from: %{id: user_id}, query: query}, context) do
    IO.puts("Inline query for '#{query}' from user [#{user_id}]")
    response = case get_google_api_key(user_id) |> Search.find_images(query) do
      {:error, nil} -> error_response()
      {:ok, items} -> as_query_results(items)
    end
    answer_inline_query(context, response)
  end

  defp get_google_api_key(_user_id) do
    Application.fetch_env!(:image_bot, :google_key)
  end

  defp as_query_results(items) do
    Enum.map(items, fn item ->
      %ExGram.Model.InlineQueryResultPhoto{
        id: UUID.uuid4(),
        type: "photo",
        photo_url: item.link,
        thumb_url: item.image.thumbnailLink,
        photo_width: item.image.width,
        photo_height: item.image.height
      }
    end)
  end

  defp error_response() do
    [%ExGram.Model.InlineQueryResultArticle{
      title: "Error",
      input_message_content: %ExGram.Model.InputTextMessageContent{
        message_text: "Something's fucky!"
      }
    }]
  end
end
