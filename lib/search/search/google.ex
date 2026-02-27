defmodule Search.Google do
  require Logger

  def find_images(api_key, query) do
    :telemetry.span([:image_bot, :google_api_call], %{}, fn ->
      result = do_find_images(api_key, query)

      status =
        case result do
          {:ok, _} -> :ok
          {:error, 400} -> 400
          {:error, 403} -> 403
          {:error, 429} -> 429
          {:error, _} -> :other
        end

      {result, %{status: status}}
    end)
  end

  defp do_find_images(api_key, query) do
    res =
      GoogleApi.CustomSearch.V1.Connection.new()
      |> GoogleApi.CustomSearch.V1.Api.Cse.search_cse_list(params(api_key, query))

    case res do
      {:error, response} ->
        Logger.warn("Google API call failed: #{response.body}")
        {:error, response.status}

      {:ok, response} ->
        {:ok, response.items}
    end
  end

  defp params(api_key, query) do
    [
      cx: "016322137100648159445:e9nsxf_q_-m",
      searchType: "image",
      key: api_key,
      q: query
    ]
  end
end
