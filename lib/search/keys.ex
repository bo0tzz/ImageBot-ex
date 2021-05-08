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

  @impl true
  def handle_cast({:add, {id, key}}, %Keys{key_mappings: mappings} = state) do
    mappings =
      Map.update(mappings, id, [{key, 0}], fn keys ->
        [{key, 0} | keys]
      end)

    {
      :noreply,
      %{state | key_mappings: mappings},
      {:continue, :save}
    }
  end

  @impl true
  def handle_cast({:mark_limited, id, key}, %Keys{key_mappings: mappings} = state) do
    mappings =
      case Map.get(mappings, id) do
        nil ->
          mark_limited(mappings, :shared, key)

        keys ->
          case Enum.any?(keys, &match?({^key, _}, &1)) do
            false -> mark_limited(mappings, :shared, key)
            true -> mark_limited(mappings, id, key)
          end
      end

    {
      :noreply,
      %{state | key_mappings: mappings},
      {:continue, :save}
    }
  end

  defp mark_limited(mappings, id, key) do
    until = DateTime.utc_now() |> DateTime.add(86_400, :second) |> DateTime.to_unix()

    Map.update(mappings, id, [], fn keys ->
      Enum.map(keys, fn k ->
        case k do
          {^key, 0} -> {key, until}
          pass -> pass
        end
      end)
    end)
  end

  @impl true
  def handle_cast({:mark_bad, id, key}, %Keys{key_mappings: mappings} = state) do
    Logger.warn("Marking key [#{key}] as bad")

    mappings =
      case Map.get(mappings, id) do
        nil ->
          reject_key(mappings, :shared, key)

        keys ->
          case Enum.any?(keys, &match?({^key, _}, &1)) do
            false ->
              reject_key(mappings, :shared, key)

            true ->
              reject_key(mappings, id, key)
          end
      end

    {
      :noreply,
      %{state | key_mappings: mappings},
      {:continue, :save}
    }
  end

  defp reject_key(mappings, id, key) do
    Map.update(
      mappings,
      id,
      [],
      fn keys ->
        Enum.reject(keys, &match?({^key, _}, &1))
      end
    )
  end

  @impl true
  def handle_call({:get_key, id}, _, %Keys{key_mappings: mappings} = state) do
    {key, mappings} =
      case find_active_key(mappings, :shared) do
        {nil, mappings} -> find_active_key(mappings, id)
        km -> km
      end

    {
      :reply,
      {:ok, key},
      %{state | key_mappings: mappings}
    }
  end

  defp find_active_key(mappings, id) do
    case Map.get(mappings, id) do
      nil ->
        {nil, mappings}

      keys ->
        {key, keys} = first_active_key(keys)
        {key, Map.put(mappings, id, keys)}
    end
  end

  defp first_active_key([]), do: {nil, []}
  defp first_active_key([{key, 0} | _rest] = keys), do: {key, keys}

  defp first_active_key([{key, inactive_until} = curr_key | rest]) do
    case DateTime.utc_now() |> DateTime.to_unix() do
      now when now > inactive_until ->
        {key, [{key, 0} | rest]}

      _ ->
        {key, rest} = first_active_key(rest)
        {key, [curr_key | rest]}
    end
  end

  defp load_keys(path) do
    case File.read(path) do
      {:ok, bin} ->
        Logger.info("Loading keys database from path #{path}")
        :erlang.binary_to_term(bin)

      {:error, reason} ->
        Logger.warn("Could not read keys database at path #{path}: #{:file.format_error(reason)}")
        %{}
    end
  end

  defp save(%Keys{storage_path: path, key_mappings: keys} = state) do
    Logger.debug("Saving state: #{inspect(state)}")
    data = :erlang.term_to_binary(keys)

    case File.write(path, data) do
      :ok ->
        Logger.info("Saved api key data")
        :ok

      {:error, reason} ->
        Logger.error("Failed to write keys database to #{path}: #{:file.format_error(reason)}")
    end
  end

  def add(id, key), do: GenServer.cast(__MODULE__, {:add, {id, key}})
  def add(key), do: GenServer.cast(__MODULE__, {:add, {:shared, key}})

  def get_key(id), do: GenServer.call(__MODULE__, {:get_key, id})

  def mark_bad(id, key), do: GenServer.cast(__MODULE__, {:mark_bad, id, key})
  def mark_limited(id, key), do: GenServer.cast(__MODULE__, {:mark_limited, id, key})
end
