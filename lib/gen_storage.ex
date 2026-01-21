defmodule Storage.Writer do
  use GenServer

  @file "data/raw/pages.jsonl"

  def start_link(_),
    do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def write(page),
    do: GenServer.cast(__MODULE__, {:write, page})

  def init(_) do
    File.mkdir_p!("data/raw")
    {:ok, File.open!(@file, [:append, :utf8])}
  end

  def handle_cast({:write, page}, file) do
    IO.write(file, Jason.encode!(page) <> "\n")
    {:noreply, file}
  end
end
