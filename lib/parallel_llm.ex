defmodule Crawler.ParallelLLM do
  def crawl(start_url, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 2)
    concurrency = Keyword.get(opts, :concurrency, 5)
    same_domain = Keyword.get(opts, :same_domain, true)
    respect_robots = Keyword.get(opts, :respect_robots, true)

    Crawler.Progress.reset()
    Crawler.Metrics.reset()

    do_crawl(%{
      pending: [start_url],
      seen: MapSet.new([start_url]),
      depth: 0,
      count: 0,
      base_url: start_url,
      same_domain: same_domain,
      respect_robots: respect_robots
    }, max_depth, concurrency)
  end

  defp do_crawl(%{pending: [], count: count}, _max_depth, _concurrency) do
    {:ok, %{pages_saved: count}}
  end

  defp do_crawl(%{depth: depth} = state, max_depth, _concurrency) when depth >= max_depth do
    {:ok, %{pages_saved: state.count}}
  end

  defp do_crawl(state, max_depth, concurrency) do
    batch = Enum.take(state.pending, concurrency)
    remaining = Enum.drop(state.pending, concurrency)

    Crawler.Progress.set_pending(length(remaining))

    results =
      batch
      |> Enum.map(fn url ->
        Task.async(fn -> fetch_and_save(url, state.respect_robots) end)
      end)
      |> Task.await_many(30_000)

    {new_links, saved_count} =
      Enum.reduce(results, {[], 0}, fn result, {links_acc, count_acc} ->
        case result do
          {:ok, links} -> {links_acc ++ links, count_acc + 1}
          {:error, _} -> {links_acc, count_acc}
        end
      end)

    filtered_links =
      new_links
      |> then(fn links ->
        if state.same_domain do
          Crawler.DomainFilter.filter_same_domain(links, state.base_url)
        else
          links
        end
      end)
      |> Crawler.URLFilter.filter()
      |> Enum.filter(&(!MapSet.member?(state.seen, &1)))

    new_seen = Enum.reduce(filtered_links, state.seen, &MapSet.put(&2, &1))

    new_state = %{state |
      pending: remaining ++ filtered_links,
      seen: new_seen,
      count: state.count + saved_count,
      depth: if(remaining == [], do: state.depth + 1, else: state.depth)
    }

    do_crawl(new_state, max_depth, concurrency)
  end

  defp fetch_and_save(url, respect_robots) do
    allowed = if respect_robots, do: Crawler.Robots.allowed?(url), else: true

    if allowed do
      Crawler.Metrics.time(:fetch_time, fn ->
        case Crawler.Fetcher.fetch_full(url) do
          {:ok, page_data} ->
            extracted = Crawler.ContentExtractor.extract(page_data.body)

            record = %{
              url: url,
              title: extracted.title,
              description: extracted.description,
              content: extracted.content,
              headings: extracted.headings,
              links: page_data.links,
              crawled_at: DateTime.utc_now() |> DateTime.to_iso8601()
            }

            Storage.Writer.write(record)
            Crawler.Progress.page_done()
            Crawler.Metrics.record(:pages_saved)
            {:ok, page_data.links}

          {:error, reason} ->
            Crawler.Metrics.record(:fetch_errors)
            {:error, reason}
        end
      end)
    else
      Crawler.Metrics.record(:robots_blocked)
      {:error, :blocked_by_robots}
    end
  end
end
