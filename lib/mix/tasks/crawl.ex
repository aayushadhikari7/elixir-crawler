defmodule Mix.Tasks.Crawl do
  use Mix.Task

  @shortdoc "Crawl a URL and save for LLM processing"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, [url | _], _} =
      OptionParser.parse(args,
        strict: [depth: :integer, delay: :integer, export: :string],
        aliases: [d: :depth, e: :export]
      )

    depth = Keyword.get(opts, :depth, 2)
    delay = Keyword.get(opts, :delay, 1000)
    export = Keyword.get(opts, :export, "jsonl")

    IO.puts("Crawling #{url} (depth: #{depth}, delay: #{delay}ms)")

    {:ok, result} = Crawler.LLM.crawl(url, max_depth: depth, delay: delay)

    IO.puts("Saved #{result.pages_saved} pages to data/raw/pages.jsonl")

    if export != "jsonl" do
      records = Crawler.Export.read_jsonl()

      case export do
        "txt" ->
          {:ok, path} = Crawler.Export.to_txt(records)
          IO.puts("Exported to #{path}")

        "md" ->
          {:ok, path} = Crawler.Export.to_markdown(records)
          IO.puts("Exported to #{path}")

        _ ->
          IO.puts("Unknown export format: #{export}")
      end
    end
  end
end
