defmodule Crawler.Application do
  use Application

  def start(_type, _args) do
    children = [
      Storage.Writer,
      Crawler.RateLimiter,
      Crawler.Progress,
      Crawler.Robots,
      Crawler.Cache,
      Crawler.Metrics
    ]

    opts = [strategy: :one_for_one, name: Crawler.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
