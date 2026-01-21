defmodule Crawler.Search do
  def search(query, opts \\ []) do
    path = Keyword.get(opts, :path, "data/raw/pages.jsonl")
    case_sensitive = Keyword.get(opts, :case_sensitive, false)
    limit = Keyword.get(opts, :limit, 10)

    query_normalized = if case_sensitive, do: query, else: String.downcase(query)

    path
    |> File.stream!()
    |> Stream.map(&Jason.decode!/1)
    |> Stream.filter(fn page ->
      content = if case_sensitive, do: page["content"], else: String.downcase(page["content"] || "")
      title = if case_sensitive, do: page["title"], else: String.downcase(page["title"] || "")
      String.contains?(content, query_normalized) or String.contains?(title, query_normalized)
    end)
    |> Stream.map(fn page ->
      %{
        url: page["url"],
        title: page["title"],
        snippet: extract_snippet(page["content"], query, 150)
      }
    end)
    |> Enum.take(limit)
  end

  def count(query, opts \\ []) do
    path = Keyword.get(opts, :path, "data/raw/pages.jsonl")

    path
    |> File.stream!()
    |> Stream.map(&Jason.decode!/1)
    |> Stream.filter(fn page ->
      content = String.downcase(page["content"] || "")
      String.contains?(content, String.downcase(query))
    end)
    |> Enum.count()
  end

  defp extract_snippet(content, query, length) when is_binary(content) do
    query_lower = String.downcase(query)
    content_lower = String.downcase(content)

    case :binary.match(content_lower, query_lower) do
      {pos, _} ->
        start_pos = max(0, pos - div(length, 2))
        snippet = String.slice(content, start_pos, length)
        "..." <> snippet <> "..."

      :nomatch ->
        String.slice(content, 0, length) <> "..."
    end
  end

  defp extract_snippet(_, _, _), do: ""
end
