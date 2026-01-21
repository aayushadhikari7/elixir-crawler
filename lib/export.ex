defmodule Crawler.Export do
  def to_jsonl(records, path \\ "data/export/pages.jsonl") do
    ensure_dir(path)
    content = Enum.map_join(records, "\n", &Jason.encode!/1)
    File.write!(path, content <> "\n")
    {:ok, path}
  end

  def to_txt(records, path \\ "data/export/pages.txt") do
    ensure_dir(path)

    content =
      records
      |> Enum.map_join("\n\n---\n\n", fn r ->
        """
        URL: #{r.url}
        Title: #{r.title}

        #{r.content}
        """
      end)

    File.write!(path, content)
    {:ok, path}
  end

  def to_markdown(records, path \\ "data/export/pages.md") do
    ensure_dir(path)

    content =
      records
      |> Enum.map_join("\n\n---\n\n", fn r ->
        """
        # #{r.title}

        **URL:** #{r.url}
        **Crawled:** #{r.crawled_at}

        ## Content

        #{r.content}

        ## Links

        #{Enum.map_join(r.links, "\n", &("- " <> &1))}
        """
      end)

    File.write!(path, content)
    {:ok, path}
  end

  def read_jsonl(path \\ "data/raw/pages.jsonl") do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  defp ensure_dir(path) do
    path |> Path.dirname() |> File.mkdir_p!()
  end
end
