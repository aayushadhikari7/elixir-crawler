defmodule Crawler.ContentExtractor do
  def extract(html) when is_binary(html) do
    case Floki.parse_document(html) do
      {:ok, doc} ->
        %{
          title: extract_title(doc),
          description: extract_meta(doc, "description"),
          content: extract_text(doc),
          headings: extract_headings(doc)
        }

      {:error, _} ->
        %{title: "", description: "", content: "", headings: []}
    end
  end

  defp extract_title(doc) do
    doc |> Floki.find("title") |> Floki.text() |> String.trim()
  end

  defp extract_meta(doc, name) do
    doc
    |> Floki.find("meta[name='#{name}']")
    |> Floki.attribute("content")
    |> List.first()
    |> Kernel.||("")
  end

  defp extract_text(doc) do
    doc
    |> remove_noise()
    |> Floki.text(sep: " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp extract_headings(doc) do
    doc
    |> Floki.find("h1, h2, h3")
    |> Enum.map(&Floki.text/1)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp remove_noise(doc) do
    doc
    |> Floki.filter_out("script")
    |> Floki.filter_out("style")
    |> Floki.filter_out("nav")
    |> Floki.filter_out("footer")
    |> Floki.filter_out("header")
    |> Floki.filter_out("noscript")
  end
end
