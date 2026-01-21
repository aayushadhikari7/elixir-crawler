defmodule Crawler.LinkGraph do
  def build(opts \\ []) do
    path = Keyword.get(opts, :path, "data/raw/pages.jsonl")

    path
    |> File.stream!()
    |> Stream.map(&Jason.decode!/1)
    |> Enum.reduce(%{nodes: MapSet.new(), edges: []}, fn page, acc ->
      url = page["url"]
      links = page["links"] || []

      new_nodes = Enum.reduce([url | links], acc.nodes, &MapSet.put(&2, &1))
      new_edges = Enum.map(links, fn link -> {url, link} end)

      %{acc | nodes: new_nodes, edges: acc.edges ++ new_edges}
    end)
  end

  def stats(graph) do
    %{
      nodes: MapSet.size(graph.nodes),
      edges: length(graph.edges),
      avg_outlinks: if(MapSet.size(graph.nodes) > 0, do: length(graph.edges) / MapSet.size(graph.nodes), else: 0)
    }
  end

  def most_linked(graph, limit \\ 10) do
    graph.edges
    |> Enum.map(fn {_from, to} -> to end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_url, count} -> -count end)
    |> Enum.take(limit)
  end

  def to_dot(graph, path \\ "data/export/graph.dot") do
    File.mkdir_p!(Path.dirname(path))

    nodes = graph.nodes |> MapSet.to_list() |> Enum.with_index()
    node_map = Map.new(nodes, fn {url, idx} -> {url, "n#{idx}"} end)

    node_lines = Enum.map(nodes, fn {url, idx} ->
      label = url |> URI.parse() |> Map.get(:path, "/") |> String.slice(0, 30)
      "  n#{idx} [label=\"#{label}\"];"
    end)

    edge_lines = Enum.map(graph.edges, fn {from, to} ->
      "  #{node_map[from]} -> #{node_map[to]};"
    end)

    content = """
    digraph LinkGraph {
      rankdir=LR;
      node [shape=box];
    #{Enum.join(node_lines, "\n")}
    #{Enum.join(edge_lines, "\n")}
    }
    """

    File.write!(path, content)
    {:ok, path}
  end

  def to_json(graph, path \\ "data/export/graph.json") do
    File.mkdir_p!(Path.dirname(path))

    data = %{
      nodes: MapSet.to_list(graph.nodes) |> Enum.map(&%{id: &1}),
      edges: Enum.map(graph.edges, fn {from, to} -> %{source: from, target: to} end)
    }

    File.write!(path, Jason.encode!(data, pretty: true))
    {:ok, path}
  end
end
