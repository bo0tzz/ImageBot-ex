defmodule ImageBot do
  require Logger

  @bot :image_bot

  use ExGram.Bot,
    name: @bot,
    setup_commands: true

  def bot(), do: @bot
  def me(), do: ExGram.get_me(bot: bot())

  command("donatekey", description: "Donate a shared API key to the bot")
  command("addkey", description: "Add a personal API key to the bot")
  command("feedback", description: "Send feedback about the bot")
  command("info", description: "Information about this bot")
  command("limits", description: "Information about the API limits")
  command("start", description: "Get started")

  middleware(ExGram.Middleware.IgnoreUsername)

  def handle({:inline_query, %{query: query} = msg}, context) do
    case String.trim(query) do
      "" -> nil
      _ -> handle_inline_query(msg, context)
    end
  end

  def handle({:command, :start, %{text: "limited_info_request"} = msg}, context),
    do: handle({:command, :limits, msg}, context)

  def handle({:command, :start, msg}, context), do: handle({:command, :info, msg}, context)

  def handle({:command, :limits, _msg}, context) do
    answer(
      context,
      """
      Unfortunately this bot can only make a limited number of free searches every day. For now, you'll need to wait until the limits reset, or add an API key.
      To help increase the limits for everyone, you can add extra Google API keys through the /donatekey command.
      Alternatively, if you just want to add a key for yourself, use /addkey.
      """
    )
  end

  def handle({:command, :info, _msg}, context) do
    {:ok, me} = me()

    answer(
      context,
      """
      This is a bot for searching through Google images and sending results to a group\\.
      To use it, just type @#{me.username} \\<search\\> in the chat box\\. For example, to find pictures of dogs, you could type:
      @#{me.username} dogs

      There is a limit to the amount of searches that can be done through this bot every day\\. For more detail see the /limits command\\.

      [Source code on GitHub](https://github.com/bo0tzz/ImageBot-ex)
      """,
      parse_mode: "MarkdownV2"
    )
  end

  def handle({:command, :feedback, %{text: ""}}, context),
    do:
      answer(context, """
      This command can be used to send feedback to the owner of this bot. To use it, just put your feedback after the command. For example:
      /feedback I really like this bot!
      """)

  def handle({:command, :feedback, %{from: %{id: user_id}, text: feedback}}, context) do
    Logger.info("User [#{user_id}] sent feedback [#{feedback}]")
    feedback_chat = Application.fetch_env!(:image_bot, :feedback_chat)

    ExGram.send_message(
      feedback_chat,
      """
      *User [#{user_id}](tg://user?id=#{user_id}) sent feedback:*
      #{feedback}
      """,
      parse_mode: "MarkdownV2",
      bot: bot()
    )

    answer(
      context,
      "Thank you for sending feedback! If you asked a question, we will get in touch with you soon."
    )
  end

  def handle({:command, :donatekey, %{text: ""}}, context),
    do:
      answer(
        context,
        """
        With this command, you can donate a Google API key to be added to the pool of shared keys\\. This means it will be used for requests made by all users of this bot\\.
        If you prefer to add a key for yourself only, use the /addkey command\\.
        To donate a key, send it after this command, like /donatekey MY\\_API\\_KEY\\.
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

  def handle({:command, :addkey, %{text: ""}}, context),
    do:
      answer(
        context,
        """
        With this command, you can add a personal Google API key\\. This means it will only be used for requests made by you\\.
        If you prefer to add a shared key for all users, use the /donatekey command\\.
        To add a key, send it after this command, like /addkey MY\\_API\\_KEY\\.
        To create a key, use the "Get a Key" button on [this page](https://developers.google.com/custom-search/v1/introduction#identify_your_application_to_google_with_api_key)\\.
        """,
        parse_mode: "MarkdownV2",
        disable_web_page_preview: true
      )

  def handle({:command, :addkey, %{from: %{id: user_id}, text: key}}, context) do
    Logger.info("User [#{user_id}] added a personal key")
    Search.Keys.add(user_id, key)
    answer(context, "Your key has been added!")
  end

  defp handle_inline_query(%{from: %{id: user_id}, query: query}, context) do
    Logger.info("Inline query from user [#{user_id}]")

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

          {:ok, nil} ->
            error_response("No results", "No results were found for this query")

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
