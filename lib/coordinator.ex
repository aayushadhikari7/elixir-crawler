defmodule Crawler.Coordinator do
  def crawl(start_url, max_depth \\ 2) do
    loop(%{
      pending: [start_url],
      seen: MapSet.new([start_url]),
      results: %{},
      depth: 0,
      max_depth: max_depth
    })
  end

  defp loop(%{pending: [], results: results}), do: results
  defp loop(%{depth: d, max_depth: max} = state) when d >= max do
    state.results
  end
  defp loop(state) do
    caller = self()

    state.pending
    |> Enum.each(fn url ->
      spawn(fn ->
        result = Crawler.Fetcher.fetch(url)
        send(caller, {:done, url, result})
      end)
    end)

    state
    |> collect(length(state.pending))
    |> next_level()
    |> loop()
  end

  defp collect(state, 0), do: state
  defp collect(state, remaining) do
    receive do
      {:done, url, {:ok, links}} ->
        new_state = %{state |
          results: Map.put(state.results, url, links),
          pending: []
        }
        new_links = Enum.filter(links, &(!MapSet.member?(state.seen, &1)))
        %{new_state | pending: state.pending ++ new_links}
        |> collect(remaining - 1)

      {:done, url, {:error, _}} ->
        %{state | results: Map.put(state.results, url, [])}
        |> collect(remaining - 1)
    after
      15_000 -> state
    end
  end

  defp next_level(state) do
    new_seen = Enum.reduce(state.pending, state.seen, &MapSet.put(&2, &1))
    %{state | seen: new_seen, depth: state.depth + 1}
  end
end
