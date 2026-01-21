defmodule Crawler.Parallel do
  def fetch_all(urls) do
    caller = self()

    urls
    |> Enum.each(fn url ->
      spawn(fn ->
        result = Crawler.Fetcher.fetch(url)
        send(caller, {:crawl_result, url, result})
      end)
    end)

    collect_results(length(urls), [])
  end

  defp collect_results(0, results), do: results
  defp collect_results(remaining, results) do
    receive do
      {:crawl_result, url, result} ->
        collect_results(remaining - 1, [{url, result} | results])
    after
      10_000 -> results
    end
  end
end
