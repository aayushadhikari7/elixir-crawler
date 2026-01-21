defmodule Crawler.RateLimiter do
  use GenServer

  def start_link(opts \\ []) do
    delay = Keyword.get(opts, :delay, 1000)
    GenServer.start_link(__MODULE__, %{delay: delay, domains: %{}}, name: __MODULE__)
  end

  def request(url) do
    GenServer.call(__MODULE__, {:request, url}, 30_000)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:request, url}, _from, state) do
    domain = get_domain(url)
    now = System.monotonic_time(:millisecond)
    last_request = Map.get(state.domains, domain, 0)
    wait_time = max(0, state.delay - (now - last_request))

    if wait_time > 0 do
      Process.sleep(wait_time)
    end

    new_state = %{state | domains: Map.put(state.domains, domain, System.monotonic_time(:millisecond))}
    {:reply, :ok, new_state}
  end

  defp get_domain(url) do
    URI.parse(url).host || url
  end
end
