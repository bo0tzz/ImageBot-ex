defmodule Search do
  require Logger

  def query(user_id, query) do
    case Cachex.get(:search_cache, query) do
      {:ok, nil} ->
        case search(user_id, query) do
          {:ok, items} ->
            Cachex.put(:search_cache, query, items)
            {:ok, items}

          error ->
            error
        end

      {:ok, items} ->
        Logger.info("Cache hit")
        {:ok, items}
    end
  end

  defp search(user_id, query, tries \\ 3)

  defp search(user_id, _, 0) do
    Logger.error("Query from user [#{user_id}] failed retries")
    {:error, :unknown}
  end

  defp search(user_id, query, tries) do
    Logger.debug("Searching for query '#{query}'")

    case Keys.get_key(user_id) do
      {:ok, nil} ->
        {:error, :limited}

      {:ok, key} ->
        case Search.Google.find_images(key, query) do
          {:error, error} ->
            Logger.warn("Query from user [#{user_id}] caused error #{error}!")

            case error do
              400 ->
                Keys.mark_bad(user_id, key)
                search(user_id, query, tries - 1)

              429 ->
                Keys.mark_limited(user_id, key)
                search(user_id, query, tries - 1)

              other ->
                {:error, other}
            end

          {:ok, nil} ->
            {:ok, nil}

          {:ok, items} ->
            {:ok, items}
        end
    end
  end
end
