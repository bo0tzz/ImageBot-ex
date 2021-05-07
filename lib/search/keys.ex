defmodule Search.Keys do
  use GenServer
  alias Search.Keys

  require Logger

  defstruct [
    :storage_path,
    :key_mappings
  ]

  def start_link(path), do: GenServer.start_link(__MODULE__, path, name: __MODULE__)

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)
    path = Application.fetch_env!(:image_bot, :key_db_path)

    {
      :ok,
      %Keys{
        storage_path: path,
        key_mappings: load_keys(path)
      }
    }
  end

  @impl true
  def terminate(_, state) do
    Logger.debug("Terminating keys management server")
    :ok = save(state)
  end

  @impl true
  def handle_continue(:save, state) do
    save(state)
    {:noreply, state}
  end

  defp load_keys(path) do
    case File.read(path) do
      {:ok, bin} ->
        Logger.debug("Loading keys database from path #{path}")
        :erlang.binary_to_term(bin)

      {:error, reason} ->
        Logger.warn("Could not read keys database at path #{path}: #{:file.format_error(reason)}")
        %{}
    end
  end

  defp save(%Keys{storage_path: path, key_mappings: keys}) do
    data = :erlang.term_to_binary(keys)

    case File.write(path, data) do
      :ok ->
        Logger.debug("Saved api key data")
        :ok

      {:error, reason} ->
        Logger.error("Failed to write keys database to #{path}: #{:file.format_error(reason)}")
    end
  end
end
