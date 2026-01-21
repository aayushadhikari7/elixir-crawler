defmodule Crawler do
  def fetch(url) do
    Crawler.Fetcher.fetch(url)
  end

  def fetch_async(url) do
    Crawler.Worker.fetch_async(url, self())
  end

  def fetch_all(urls) do
    Crawler.Parallel.fetch_all(urls)
  end

  def fetch_all_supervised(urls, timeout \\ 10_000) do
    Crawler.WorkerSupervisor.fetch_many_supervised(urls, timeout)
  end

  def crawl(start_url, max_depth \\ 2) do
    Crawler.Coordinator.crawl(start_url, max_depth)
  end

  def crawl_polite(start_url, opts \\ []) do
    Crawler.Polite.crawl(start_url, opts)
  end

  def receive_result(timeout \\ 5000) do
    receive do
      {:crawl_result, url, result} -> {url, result}
    after
      timeout -> {:error, :timeout}
    end
  end
end
