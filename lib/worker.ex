defmodule Crawler.Worker do
  def fetch_async(url, caller) do
    spawn(fn ->
      result = Crawler.Fetcher.fetch(url)
      send(caller, {:crawl_result, url, result})
    end)
  end
end
