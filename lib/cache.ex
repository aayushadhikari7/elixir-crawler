defmodule Crawler.Cache do
  use GenServer

  @cache_dir "data/cache"

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get(url) do
    GenServer.call(__MODULE__, {:get, url})
  end

  def put(url, data) do
    GenServer.cast(__MODULE__, {:put, url, data})
  end

  def has?(url) do
    GenServer.call(__MODULE__, {:has?, url})
  end

  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  def init(_) do
    File.mkdir_p!(@cache_dir)
    {:ok, %{hits: 0, misses: 0}}
  end

  def handle_call({:get, url}, _from, state) do
    path = cache_path(url)

    case File.read(path) do
      {:ok, content} ->
        {:reply, {:ok, Jason.decode!(content)}, %{state | hits: state.hits + 1}}

      {:error, _} ->
        {:reply, :miss, %{state | misses: state.misses + 1}}
    end
  end

  def handle_call({:has?, url}, _from, state) do
    {:reply, File.exists?(cache_path(url)), state}
  end

  def handle_call(:stats, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:put, url, data}, state) do
    path = cache_path(url)
    File.write!(path, Jason.encode!(data))
    {:noreply, state}
  end

  def handle_cast(:clear, state) do
    File.rm_rf!(@cache_dir)
    File.mkdir_p!(@cache_dir)
    {:noreply, %{state | hits: 0, misses: 0}}
  end

  defp cache_path(url) do
    hash = :crypto.hash(:md5, url) |> Base.encode16(case: :lower)
    Path.join(@cache_dir, hash <> ".json")
  end
end
