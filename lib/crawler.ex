defmodule Crawler do
  def fetch(url) do
    Crawler.Fetcher.fetch(url)
  end
end
