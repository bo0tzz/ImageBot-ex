defmodule Search do
  require Logger

  def find_images(api_key, query), do: Search.Google.find_images(api_key, query)
end
