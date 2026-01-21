defmodule Crawler.Robots do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def allowed?(url) do
    GenServer.call(__MODULE__, {:allowed?, url}, 10_000)
  end

  def init(_) do
    {:ok, %{cache: %{}}}
  end

  def handle_call({:allowed?, url}, _from, state) do
    domain = get_domain(url)
    path = URI.parse(url).path || "/"

    {rules, new_state} =
      case Map.get(state.cache, domain) do
        nil ->
          rules = fetch_robots(domain)
          {rules, %{state | cache: Map.put(state.cache, domain, rules)}}

        cached ->
          {cached, state}
      end

    allowed = check_rules(rules, path)
    {:reply, allowed, new_state}
  end

  defp fetch_robots(domain) do
    url = "https://#{domain}/robots.txt"

    case Req.get(url, receive_timeout: 5000) do
      {:ok, %{status: 200, body: body}} -> parse_robots(body)
      _ -> []
    end
  end

  defp parse_robots(body) do
    body
    |> String.split("\n")
    |> Enum.reduce(%{user_agent: nil, rules: []}, fn line, acc ->
      line = String.trim(line)

      cond do
        String.starts_with?(line, "User-agent:") ->
          %{acc | user_agent: String.trim_leading(line, "User-agent:") |> String.trim()}

        String.starts_with?(line, "Disallow:") and acc.user_agent in ["*", nil] ->
          path = String.trim_leading(line, "Disallow:") |> String.trim()
          %{acc | rules: [{:disallow, path} | acc.rules]}

        String.starts_with?(line, "Allow:") and acc.user_agent in ["*", nil] ->
          path = String.trim_leading(line, "Allow:") |> String.trim()
          %{acc | rules: [{:allow, path} | acc.rules]}

        true ->
          acc
      end
    end)
    |> Map.get(:rules)
    |> Enum.reverse()
  end

  defp check_rules(rules, path) do
    Enum.reduce_while(rules, true, fn
      {:disallow, ""}, acc -> {:cont, acc}
      {:disallow, pattern}, _acc ->
        if String.starts_with?(path, pattern), do: {:halt, false}, else: {:cont, true}
      {:allow, pattern}, _acc ->
        if String.starts_with?(path, pattern), do: {:halt, true}, else: {:cont, true}
    end)
  end

  defp get_domain(url) do
    URI.parse(url).host || ""
  end
end
