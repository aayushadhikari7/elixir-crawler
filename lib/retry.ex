defmodule Crawler.Retry do
  def with_retry(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    delay = Keyword.get(opts, :delay, 1000)
    backoff = Keyword.get(opts, :backoff, 2)

    do_retry(fun, max_attempts, delay, backoff, 1)
  end

  defp do_retry(fun, max_attempts, _delay, _backoff, attempt) when attempt > max_attempts do
    {:error, :max_retries_exceeded}
  end

  defp do_retry(fun, max_attempts, delay, backoff, attempt) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} when attempt < max_attempts ->
        wait_time = delay * :math.pow(backoff, attempt - 1) |> round()
        Process.sleep(wait_time)
        do_retry(fun, max_attempts, delay, backoff, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def fetch_with_retry(url, opts \\ []) do
    fetch_opts = Keyword.get(opts, :fetch_opts, [])

    with_retry(fn ->
      Crawler.Fetcher.fetch_full(url, fetch_opts)
    end, opts)
  end
end
