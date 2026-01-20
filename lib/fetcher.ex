defmodule Crawler.Fetcher do
  def fetch(url) do
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        links = extract_links(body, url)
        {:ok, links}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_links(html, base_url) do
    html
    |> Floki.parse_document!()
    |> Floki.find("a")
    |> Floki.attribute("href")
    |> Enum.map(&normalize_url(&1, base_url))
    |> Enum.filter(&valid_url?/1)
    |> Enum.uniq()
  end

  defp normalize_url(href, base_url) do
    cond do
      String.starts_with?(href, "http") ->
        href

      String.starts_with?(href, "//") ->
        "https:" <> href

      String.starts_with?(href, "/") ->
        base_uri = URI.parse(base_url)
        "#{base_uri.scheme}://#{base_uri.host}#{href}"

      true ->
        nil
    end
  end

  defp valid_url?(nil), do: false
  defp valid_url?(url) do
    String.starts_with?(url, "http://") or String.starts_with?(url, "https://")
  end
end
