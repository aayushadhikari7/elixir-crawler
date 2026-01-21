defmodule Crawler do
  # Basic fetching
  def fetch(url), do: Crawler.Fetcher.fetch(url)
  def fetch_full(url), do: Crawler.Fetcher.fetch_full(url)
  def fetch_async(url), do: Crawler.Worker.fetch_async(url, self())
  def fetch_all(urls), do: Crawler.Parallel.fetch_all(urls)
  def fetch_all_supervised(urls, timeout \\ 10_000), do: Crawler.WorkerSupervisor.fetch_many_supervised(urls, timeout)

  # Crawling
  def crawl(start_url, max_depth \\ 2), do: Crawler.Coordinator.crawl(start_url, max_depth)
  def crawl_polite(start_url, opts \\ []), do: Crawler.Polite.crawl(start_url, opts)
  def crawl_for_llm(start_url, opts \\ []), do: Crawler.LLM.crawl(start_url, opts)
  def crawl_parallel(start_url, opts \\ []), do: Crawler.ParallelLLM.crawl(start_url, opts)

  # Sitemap
  def sitemap(base_url), do: Crawler.Sitemap.fetch(base_url)
  def crawl_sitemap(base_url, opts \\ []), do: Crawler.Sitemap.crawl_from_sitemap(base_url, opts)

  # Export
  def export(format \\ :jsonl) do
    records = Crawler.Export.read_jsonl()
    case format do
      :jsonl -> Crawler.Export.to_jsonl(records)
      :txt -> Crawler.Export.to_txt(records)
      :md -> Crawler.Export.to_markdown(records)
      _ -> {:error, :unknown_format}
    end
  end

  # Search
  def search(query, opts \\ []), do: Crawler.Search.search(query, opts)

  # Link graph
  def graph(opts \\ []), do: Crawler.LinkGraph.build(opts)
  def graph_stats(graph), do: Crawler.LinkGraph.stats(graph)
  def graph_to_dot(graph, path \\ "data/export/graph.dot"), do: Crawler.LinkGraph.to_dot(graph, path)
  def graph_to_json(graph, path \\ "data/export/graph.json"), do: Crawler.LinkGraph.to_json(graph, path)

  # Ollama / LLM
  def summarize(text, opts \\ []), do: Crawler.Ollama.summarize(text, opts)
  def ask(text, question, opts \\ []), do: Crawler.Ollama.ask(text, question, opts)
  def process_with_ollama(opts \\ []), do: Crawler.Ollama.process_crawled(opts)
  def ollama_models, do: Crawler.Ollama.list_models()

  # Utils
  def progress, do: Crawler.Progress.get_stats()
  def metrics, do: Crawler.Metrics.get()
  def print_metrics, do: Crawler.Metrics.print()
  def cache_stats, do: Crawler.Cache.stats()
  def clear_cache, do: Crawler.Cache.clear()

  def receive_result(timeout \\ 5000) do
    receive do
      {:crawl_result, url, result} -> {url, result}
    after
      timeout -> {:error, :timeout}
    end
  end
end
