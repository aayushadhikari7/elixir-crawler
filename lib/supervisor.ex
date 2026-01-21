defmodule Crawler.WorkerSupervisor do
  def fetch_supervised(url, caller, timeout \\ 10_000) do
    task = Task.async(fn ->
      Crawler.Fetcher.fetch(url)
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} ->
        send(caller, {:crawl_result, url, result})
      nil ->
        send(caller, {:crawl_result, url, {:error, :timeout}})
    end
  end

  def fetch_many_supervised(urls, timeout \\ 10_000) do
    urls
    |> Enum.map(fn url ->
      Task.async(fn ->
        {url, Crawler.Fetcher.fetch(url)}
      end)
    end)
    |> Task.yield_many(timeout)
    |> Enum.map(fn {task, result} ->
      case result do
        {:ok, val} -> val
        nil ->
          Task.shutdown(task, :brutal_kill)
          {:unknown, {:error, :timeout}}
      end
    end)
  end
end
