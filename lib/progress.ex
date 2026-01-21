defmodule Crawler.Progress do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{crawled: 0, pending: 0, started: nil}, name: __MODULE__)
  end

  def reset do
    GenServer.cast(__MODULE__, :reset)
  end

  def set_pending(count) do
    GenServer.cast(__MODULE__, {:set_pending, count})
  end

  def page_done do
    GenServer.cast(__MODULE__, :page_done)
  end

  def get_stats do
    GenServer.call(__MODULE__, :stats)
  end

  def print_status do
    stats = get_stats()
    elapsed = if stats.started, do: System.monotonic_time(:second) - stats.started, else: 0
    rate = if elapsed > 0, do: Float.round(stats.crawled / elapsed, 2), else: 0.0

    IO.puts("\rCrawled: #{stats.crawled} | Pending: #{stats.pending} | Rate: #{rate}/s")
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast(:reset, _state) do
    {:noreply, %{crawled: 0, pending: 0, started: System.monotonic_time(:second)}}
  end

  def handle_cast({:set_pending, count}, state) do
    {:noreply, %{state | pending: count}}
  end

  def handle_cast(:page_done, state) do
    {:noreply, %{state | crawled: state.crawled + 1, pending: max(0, state.pending - 1)}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, state, state}
  end
end
