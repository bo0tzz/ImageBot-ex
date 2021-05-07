defmodule ImageBot do
  require Logger

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
    Logger.info("Inline query for '#{query}' from user [#{user_id}]")

    response =
      case Cachex.get(:search_cache, query) do
        {:ok, nil} ->
          search(user_id, query)

        {:ok, response} ->
          Logger.debug("Cache hit for query '#{query}'")
          response
      end

    answer_inline_query(context, response)
  end

  defp search(user_id, query) do
    Logger.debug("Searching for query '#{query}'")

    case Search.Keys.get_key(user_id) do
      {:ok, nil} ->
        error_response(:limited)

      {:ok, key} ->
        case Search.find_images(key, query) do
          {:error, _response} ->
            Logger.warn("Query #{query} from user #{user_id} caused error!")
            error_response()

          {:ok, items} ->
            results = as_query_results(items)
            Cachex.put(:search_cache, query, results)
            results
        end
    end
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

  defp error_response(:limited),
    do: error_response("The bot has reached its request limit for today!", "Try again later!")

  defp error_response(), do: error_response("Error", "An unexpected error occurred!")

  defp error_response(title, message),
    do: [
      %ExGram.Model.InlineQueryResultArticle{
        type: "article",
        id: UUID.uuid4(),
        title: title,
        description: message,
        input_message_content: %ExGram.Model.InputTextMessageContent{
          message_text: title <> "\n" <> message
        }
      }
    ]
end
