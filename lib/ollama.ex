defmodule Crawler.Ollama do
  @base_url "http://localhost:11434"

  def summarize(text, opts \\ []) do
    model = Keyword.get(opts, :model, "llama3.2")
    prompt = """
    Summarize the following text in 2-3 sentences:

    #{String.slice(text, 0, 4000)}
    """

    generate(prompt, model)
  end

  def extract_info(text, opts \\ []) do
    model = Keyword.get(opts, :model, "llama3.2")
    prompt = """
    Extract key information from this text. Return as JSON with keys: topics, entities, key_points

    #{String.slice(text, 0, 4000)}
    """

    generate(prompt, model)
  end

  def ask(text, question, opts \\ []) do
    model = Keyword.get(opts, :model, "llama3.2")
    prompt = """
    Based on this text, answer the question.

    Text:
    #{String.slice(text, 0, 4000)}

    Question: #{question}
    """

    generate(prompt, model)
  end

  def generate(prompt, model \\ "llama3.2") do
    body = Jason.encode!(%{
      model: model,
      prompt: prompt,
      stream: false
    })

    case Req.post("#{@base_url}/api/generate", body: body, headers: [{"content-type", "application/json"}], receive_timeout: 120_000) do
      {:ok, %{status: 200, body: %{"response" => response}}} ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def process_crawled(opts \\ []) do
    path = Keyword.get(opts, :path, "data/raw/pages.jsonl")
    model = Keyword.get(opts, :model, "llama3.2")
    limit = Keyword.get(opts, :limit, 10)
    output = Keyword.get(opts, :output, "data/processed/summaries.jsonl")

    File.mkdir_p!(Path.dirname(output))

    results =
      path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Stream.take(limit)
      |> Enum.map(fn page ->
        IO.puts("Processing: #{page["url"]}")

        case summarize(page["content"] || "", model: model) do
          {:ok, summary} ->
            result = %{
              url: page["url"],
              title: page["title"],
              summary: summary,
              processed_at: DateTime.utc_now() |> DateTime.to_iso8601()
            }

            File.write!(output, Jason.encode!(result) <> "\n", [:append])
            {:ok, result}

          {:error, reason} ->
            {:error, page["url"], reason}
        end
      end)

    success = Enum.count(results, &match?({:ok, _}, &1))
    {:ok, %{processed: success, total: limit}}
  end

  def list_models do
    case Req.get("#{@base_url}/api/tags") do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, Enum.map(models, & &1["name"])}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
