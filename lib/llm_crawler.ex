defmodule Crawler.LLM do
  def crawl(start_url, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 2)
    delay = Keyword.get(opts, :delay, 1000)
    same_domain = Keyword.get(opts, :same_domain, true)

    Crawler.Progress.reset()

    do_crawl(%{
      pending: [{start_url, 0}],
      seen: MapSet.new([start_url]),
      count: 0,
      base_url: start_url,
      same_domain: same_domain
    }, max_depth, delay)
  end

  defp do_crawl(%{pending: [], count: count}, _max_depth, _delay) do
    {:ok, %{pages_saved: count}}
  end

  defp do_crawl(state, max_depth, delay) do
    {url, depth} = hd(state.pending)
    remaining = tl(state.pending)

    Crawler.Progress.set_pending(length(remaining))

    if depth >= max_depth do
      do_crawl(%{state | pending: remaining}, max_depth, delay)
    else
      Process.sleep(delay)

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

          filtered_links =
            if state.same_domain do
              Crawler.DomainFilter.filter_same_domain(page_data.links, state.base_url)
            else
              page_data.links
            end

          new_links =
            filtered_links
            |> Enum.filter(&(!MapSet.member?(state.seen, &1)))
            |> Enum.map(&{&1, depth + 1})

          new_seen = Enum.reduce(filtered_links, state.seen, &MapSet.put(&2, &1))

          new_state = %{state |
            pending: remaining ++ new_links,
            seen: new_seen,
            count: state.count + 1
          }

          do_crawl(new_state, max_depth, delay)

        {:error, _reason} ->
          do_crawl(%{state | pending: remaining}, max_depth, delay)
      end
    end
  end
end
