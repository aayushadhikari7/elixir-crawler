defmodule Crawler.Polite do
  def crawl(start_url, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 2)
    delay = Keyword.get(opts, :delay, 1000)

    {:ok, _pid} = Crawler.RateLimiter.start_link(delay: delay)

    do_crawl(%{
      pending: [{start_url, 0}],
      seen: MapSet.new([start_url]),
      results: %{}
    }, max_depth)
  end

  defp do_crawl(%{pending: []}, _max_depth), do: {:ok, %{}}
  defp do_crawl(%{pending: [], results: results}, _max_depth), do: {:ok, results}
  defp do_crawl(state, max_depth) do
    {url, depth} = hd(state.pending)
    remaining = tl(state.pending)

    if depth >= max_depth do
      do_crawl(%{state | pending: remaining}, max_depth)
    else
      Crawler.RateLimiter.request(url)

      case Crawler.Fetcher.fetch(url) do
        {:ok, links} ->
          new_links =
            links
            |> Enum.filter(&(!MapSet.member?(state.seen, &1)))
            |> Enum.map(&{&1, depth + 1})

          new_seen = Enum.reduce(links, state.seen, &MapSet.put(&2, &1))

          new_state = %{
            pending: remaining ++ new_links,
            seen: new_seen,
            results: Map.put(state.results, url, links)
          }

          do_crawl(new_state, max_depth)

        {:error, _reason} ->
          new_state = %{state |
            pending: remaining,
            results: Map.put(state.results, url, [])
          }
          do_crawl(new_state, max_depth)
      end
    end
  end
end
