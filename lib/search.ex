defmodule Search do
  require Logger

  def query(user_id, query) do
    case Cachex.get(:search_cache, query) do
      {:ok, nil} ->
        :telemetry.execute([:image_bot, :cache_miss], %{count: 1}, %{})

        result =
          :telemetry.span([:image_bot, :search], %{}, fn ->
            res = search(user_id, query)

            status =
              case res do
                {:ok, _} -> :ok
                {:error, :limited} -> :limited
                {:error, :unknown} -> :unknown
                {:error, _} -> :error
              end

            {res, %{status: status}}
          end)

        case result do
          {:ok, items} ->
            Cachex.put(:search_cache, query, items)
            {:ok, items}

          error ->
            error
        end

      {:ok, items} ->
        :telemetry.execute([:image_bot, :cache_hit], %{count: 1}, %{})
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
              c when c in [400, 403] ->
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
