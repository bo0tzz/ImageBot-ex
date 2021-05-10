defmodule Search.Google do
  require Logger

  def find_images(api_key, query) do
    res =
      GoogleApi.CustomSearch.V1.Connection.new()
      |> GoogleApi.CustomSearch.V1.Api.Cse.search_cse_list(params(api_key, query))

    case res do
      {:error, response} ->
        Logger.warn("Google API call failed", body: response.body)
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
