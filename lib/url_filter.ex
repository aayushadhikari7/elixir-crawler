defmodule Crawler.URLFilter do
  def filter(urls, opts \\ []) do
    include = Keyword.get(opts, :include, [])
    exclude = Keyword.get(opts, :exclude, [])
    extensions = Keyword.get(opts, :skip_extensions, ~w(.pdf .jpg .jpeg .png .gif .zip .tar .gz .mp3 .mp4 .avi))

    urls
    |> maybe_filter_include(include)
    |> maybe_filter_exclude(exclude)
    |> filter_extensions(extensions)
  end

  defp maybe_filter_include(urls, []), do: urls
  defp maybe_filter_include(urls, patterns) do
    Enum.filter(urls, fn url ->
      Enum.any?(patterns, &matches?(url, &1))
    end)
  end

  defp maybe_filter_exclude(urls, []), do: urls
  defp maybe_filter_exclude(urls, patterns) do
    Enum.reject(urls, fn url ->
      Enum.any?(patterns, &matches?(url, &1))
    end)
  end

  defp filter_extensions(urls, extensions) do
    Enum.reject(urls, fn url ->
      path = URI.parse(url).path || ""
      Enum.any?(extensions, &String.ends_with?(path, &1))
    end)
  end

  defp matches?(url, pattern) when is_binary(pattern) do
    String.contains?(url, pattern)
  end

  defp matches?(url, %Regex{} = pattern) do
    Regex.match?(pattern, url)
  end
end
