defmodule Crawler.Metrics do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def record(event, value \\ 1) do
    GenServer.cast(__MODULE__, {:record, event, value})
  end

  def time(event, fun) do
    start = System.monotonic_time(:millisecond)
    result = fun.()
    elapsed = System.monotonic_time(:millisecond) - start
    record(event, elapsed)
    result
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def reset do
    GenServer.cast(__MODULE__, :reset)
  end

  def print do
    stats = get()

    IO.puts("\n=== Crawler Metrics ===")

    Enum.each(stats, fn {event, data} ->
      IO.puts("#{event}:")
      IO.puts("  count: #{data.count}")
      IO.puts("  total: #{data.total}")
      IO.puts("  avg: #{Float.round(data.avg, 2)}")
      IO.puts("  min: #{data.min}")
      IO.puts("  max: #{data.max}")
    end)
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_cast({:record, event, value}, state) do
    updated = Map.update(state, event, new_metric(value), fn existing ->
      update_metric(existing, value)
    end)
    {:noreply, updated}
  end

  def handle_cast(:reset, _state) do
    {:noreply, %{}}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  defp new_metric(value) do
    %{count: 1, total: value, min: value, max: value, avg: value / 1}
  end

  defp update_metric(m, value) do
    count = m.count + 1
    total = m.total + value
    %{
      count: count,
      total: total,
      min: min(m.min, value),
      max: max(m.max, value),
      avg: total / count
    }
  end
end
