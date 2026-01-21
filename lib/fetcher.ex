defmodule Crawler.Fetcher do
  def fetch_full(url, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)

    try do
      case Req.get(url, receive_timeout: timeout) do
        {:ok, %{status: status, body: body}} when status in 200..299 ->
          {:ok, doc} = Floki.parse_document(body)
          title = doc |> Floki.find("title") |> Floki.text() |> String.trim()
          links = extract_links(body, url)

          {:ok, %{
            url: url,
            title: title,
            body: body,
            links: links,
            status: status
          }}

        {:ok, %{status: status}} when status in 300..399 ->
          {:error, {:redirect, status}}

        {:ok, %{status: status}} ->
          {:error, {:http_error, status}}

        {:error, %{reason: reason}} ->
          {:error, reason}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e -> {:error, {:exception, Exception.message(e)}}
    end
  end

  def fetch(url, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)

    try do
      case Req.get(url, receive_timeout: timeout) do
        {:ok, %{status: status, body: body}} when status in 200..299 ->
          links = extract_links(body, url)
          {:ok, links}

        {:ok, %{status: status}} when status in 300..399 ->
          {:error, {:redirect, status}}

        {:ok, %{status: status}} ->
          {:error, {:http_error, status}}

        {:error, %{reason: reason}} ->
          {:error, reason}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e -> {:error, {:exception, Exception.message(e)}}
    end
  end

  defp extract_links(body, _base_url) when not is_binary(body), do: []
  defp extract_links(html, base_url) do
    case Floki.parse_document(html) do
      {:ok, doc} ->
        doc
        |> Floki.find("a")
        |> Floki.attribute("href")
        |> Enum.map(&normalize_url(&1, base_url))
        |> Enum.filter(&valid_url?/1)
        |> Enum.uniq()

      {:error, _} ->
        []
    end
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
