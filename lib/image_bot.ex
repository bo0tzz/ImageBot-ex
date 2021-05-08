defmodule ImageBot do
  require Logger

  @bot :image_bot

  use ExGram.Bot,
    name: @bot,
    setup_commands: true

  def bot(), do: @bot

  command("donatekey", description: "Donate a shared API key to the bot")

  def handle({:inline_query, %{query: query} = msg}, context) do
    case String.trim(query) do
      "" -> nil
      _ -> handle_inline_query(msg, context)
    end
  end

  def handle({:command, "start", %{text: "limited_info_request"}}, context) do
    answer(
      context,
      """
      Unfortunately this bot can only make a limited number of free searches every day. For now, you'll need to wait until the limits reset.
      In the near future there will be the possibility to add your own API keys to avoid being limited.
      """
    )
  end

  def handle({:command, :donatekey, %{text: ""}}, context),
    do:
      answer(
        context,
        """
        With this command, you can donate a Google API key to be added to the pool of shared keys\\.
        This means it will be used for requests made by all users of this bot\\. If you prefer to add a key for yourself only, use the /addkey command\\.
        To donate a key, simply send it after this command, like /donatekey MY\\_API\\_KEY\\.
        To create a key, use the "Get a Key" button on [this page](https://developers.google.com/custom-search/v1/introduction#identify_your_application_to_google_with_api_key)\\.
        """,
        parse_mode: "MarkdownV2",
        disable_web_page_preview: true
      )

  def handle({:command, :donatekey, %{from: user, text: key}}, context) do
    Logger.info("User [#{inspect(user)}] graciously donated a key! <3")
    Search.Keys.add(key)
    answer(context, "Thank you so much for donating a key! We love you <3")
  end

  defp handle_inline_query(%{from: %{id: user_id}, query: query}, context) do
    Logger.info("Inline query for '#{query}' from user [#{user_id}]")

    {response, opts} =
      case Cachex.get(:search_cache, query) do
        {:ok, nil} ->
          search(user_id, query)

        {:ok, response} ->
          Logger.debug("Cache hit for query '#{query}'")
          {response, []}
      end

    answer_inline_query(context, response, opts)
  end

  defp search(user_id, query, tries \\ 3)

  defp search(user_id, query, 0) do
    Logger.error("Query '#{query}' from user [#{user_id}] failed retries")
    error_response("Error", "Something went wrong, please try again")
  end

  defp search(user_id, query, tries) do
    Logger.debug("Searching for query '#{query}'")

    case Search.Keys.get_key(user_id) do
      {:ok, nil} ->
        error_response(:limited)

      {:ok, key} ->
        case Search.find_images(key, query) do
          {:error, response} ->
            Logger.warn("Query '#{query}' from user [#{user_id}] caused error #{response}!")

            case response do
              400 ->
                Search.Keys.mark_bad(user_id, key)
                search(user_id, query, tries - 1)

              429 ->
                Search.Keys.mark_limited(user_id, key)
                search(user_id, query, tries - 1)

              other ->
                error_response(
                  "Error #{other}",
                  "An unexpected error with code #{other} occurred"
                )
            end

          {:ok, items} ->
            results = as_query_results(items)
            Cachex.put(:search_cache, query, results)
            {results, []}
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
    do:
      {[],
       [
         switch_pm_text: "Request limit reached. Click here for more information.",
         switch_pm_parameter: "limited_info_request"
       ]}

  defp error_response(), do: error_response("Error", "An unexpected error occurred!")

  defp error_response(title, message, opts \\ []),
    do:
      {[
         %ExGram.Model.InlineQueryResultArticle{
           type: "article",
           id: UUID.uuid4(),
           title: title,
           description: message,
           input_message_content: %ExGram.Model.InputTextMessageContent{
             message_text: title <> "\n" <> message
           }
         }
       ], Keyword.merge([cache_time: 0], opts)}
end
