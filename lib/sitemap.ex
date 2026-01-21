defmodule Crawler.Sitemap do
  def fetch(base_url) do
    sitemap_url = URI.merge(base_url, "/sitemap.xml") |> to_string()

    case Req.get(sitemap_url) do
      {:ok, %{status: 200, body: body}} ->
        urls = parse_sitemap(body)
        {:ok, urls}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def crawl_from_sitemap(base_url, opts \\ []) do
    case fetch(base_url) do
      {:ok, urls} ->
        max_pages = Keyword.get(opts, :max_pages, 100)
        delay = Keyword.get(opts, :delay, 1000)

        urls_to_crawl = Enum.take(urls, max_pages)

        Crawler.Progress.reset()

        results =
          urls_to_crawl
          |> Enum.with_index(1)
          |> Enum.map(fn {url, idx} ->
            Process.sleep(delay)
            IO.puts("Crawling #{idx}/#{length(urls_to_crawl)}: #{url}")

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
                {:ok, url}

              {:error, reason} ->
                {:error, url, reason}
            end
          end)

        success_count = Enum.count(results, &match?({:ok, _}, &1))
        {:ok, %{pages_saved: success_count, total_in_sitemap: length(urls)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_sitemap(xml) do
    case Floki.parse_document(xml) do
      {:ok, doc} ->
        doc
        |> Floki.find("url loc")
        |> Enum.map(&Floki.text/1)
        |> Enum.map(&String.trim/1)

      {:error, _} ->
        []
    end
  end
end
