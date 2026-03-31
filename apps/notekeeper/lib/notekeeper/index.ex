defmodule Notekeeper.Index do
  @moduledoc """
  Lightweight indexes for fast note lookup by tag and date.

  Indexes are derived from the materialised note state. They are
  disposable — rebuilt from notes if the index files are missing.
  """

  alias Notekeeper.Note

  @doc "Rebuild both indexes from the current notes map."
  @spec rebuild(%{String.t() => Note.t()}) :: {map(), map()}
  def rebuild(notes_map) do
    by_tag = build_tag_index(notes_map)
    by_date = build_date_index(notes_map)
    {by_tag, by_date}
  end

  @doc "Save indexes to disk."
  @spec save(String.t(), map(), map()) :: :ok
  def save(data_dir, by_tag, by_date) do
    dir = Path.join(data_dir, "index")
    File.mkdir_p!(dir)

    File.write!(Path.join(dir, "by_tag.json"), Jason.encode!(by_tag, pretty: true))
    File.write!(Path.join(dir, "by_date.json"), Jason.encode!(by_date, pretty: true))
    :ok
  end

  @doc "Load tag index from disk."
  @spec load_tag_index(String.t()) :: map()
  def load_tag_index(data_dir) do
    load_index(Path.join([data_dir, "index", "by_tag.json"]))
  end

  @doc "Load date index from disk."
  @spec load_date_index(String.t()) :: map()
  def load_date_index(data_dir) do
    load_index(Path.join([data_dir, "index", "by_date.json"]))
  end

  defp build_tag_index(notes_map) do
    notes_map
    |> Map.values()
    |> Enum.flat_map(fn note ->
      Enum.map(note.tags, fn tag -> {tag, note.id} end)
    end)
    |> Enum.group_by(fn {tag, _} -> tag end, fn {_, id} -> id end)
  end

  defp build_date_index(notes_map) do
    notes_map
    |> Map.values()
    |> Enum.group_by(fn note -> String.slice(note.modified, 0, 10) end, fn note -> note.id end)
  end

  defp load_index(path) do
    case File.read(path) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, map} when is_map(map) -> map
          _ -> %{}
        end

      _ ->
        %{}
    end
  end
end
