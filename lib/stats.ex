defmodule Crawler.Stats do
  def benchmark(urls, opts \\ []) do
    concurrency = Keyword.get(opts, :concurrency, [1, 10, 50, 100])

    Enum.map(concurrency, fn n ->
      {time, results} = :timer.tc(fn ->
        fetch_with_concurrency(urls, n)
      end)

      %{
        concurrency: n,
        time_ms: div(time, 1000),
        pages: length(results),
        pages_per_second: length(results) / (time / 1_000_000)
      }
    end)
  end

  defp fetch_with_concurrency(urls, n) do
    urls
    |> Enum.chunk_every(n)
    |> Enum.flat_map(fn chunk ->
      chunk
      |> Enum.map(&Task.async(fn -> {&1, Crawler.Fetcher.fetch(&1)} end))
      |> Task.await_many(30_000)
    end)
  end

  def summarize(results) when is_map(results) do
    total_pages = map_size(results)
    total_links = results |> Map.values() |> List.flatten() |> length()
    unique_links = results |> Map.values() |> List.flatten() |> Enum.uniq() |> length()

    %{
      pages_crawled: total_pages,
      total_links_found: total_links,
      unique_links: unique_links,
      avg_links_per_page: if(total_pages > 0, do: total_links / total_pages, else: 0)
    }
  end

  def print_benchmark(results) do
    IO.puts("\n--- Benchmark Results ---")
    IO.puts("Concurrency | Time (ms) | Pages | Pages/sec")
    IO.puts(String.duplicate("-", 50))

    Enum.each(results, fn r ->
      IO.puts("#{String.pad_leading(to_string(r.concurrency), 11)} | " <>
              "#{String.pad_leading(to_string(r.time_ms), 9)} | " <>
              "#{String.pad_leading(to_string(r.pages), 5)} | " <>
              "#{Float.round(r.pages_per_second, 2)}")
    end)
  end
end
