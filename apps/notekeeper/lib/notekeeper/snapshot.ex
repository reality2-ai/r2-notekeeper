defmodule Notekeeper.Snapshot do
  @moduledoc """
  Materialised state snapshots for fast startup.

  Snapshots are derived from the event log — they are disposable and
  can be rebuilt if lost. On startup: load snapshot, replay events since
  snapshot timestamp, and the in-memory state is current.

  Atomic writes: write to temp file, then rename (no partial reads).
  """

  alias Notekeeper.Note

  @doc "Save the current notes map as a snapshot."
  @spec save(String.t(), %{String.t() => Note.t()}) :: :ok | {:error, term()}
  def save(data_dir, notes_map) do
    dir = Path.join(data_dir, "state")
    File.mkdir_p!(dir)

    notes_path = Path.join(dir, "notes.json")
    timestamp_path = Path.join(dir, "snapshot.timestamp")
    tmp_path = notes_path <> ".tmp"

    notes_list = Map.values(notes_map)
    json = Jason.encode!(notes_list, pretty: true)

    with :ok <- File.write(tmp_path, json),
         :ok <- File.rename(tmp_path, notes_path),
         :ok <- File.write(timestamp_path, DateTime.utc_now() |> DateTime.to_iso8601()) do
      :ok
    end
  end

  @doc """
  Load the snapshot. Returns `{notes_map, timestamp}` or `:none`.
  """
  @spec load(String.t()) :: {%{String.t() => Note.t()}, String.t()} | :none
  def load(data_dir) do
    notes_path = Path.join([data_dir, "state", "notes.json"])
    timestamp_path = Path.join([data_dir, "state", "snapshot.timestamp"])

    with {:ok, json} <- File.read(notes_path),
         {:ok, list} when is_list(list) <- Jason.decode(json),
         {:ok, timestamp} <- File.read(timestamp_path) do
      notes_map =
        list
        |> Enum.map(&decode_note/1)
        |> Enum.reject(&is_nil/1)
        |> Map.new(fn note -> {note.id, note} end)

      {notes_map, String.trim(timestamp)}
    else
      _ -> :none
    end
  end

  defp decode_note(map) when is_map(map) do
    %Note{
      id: map["id"],
      title: map["title"] || "",
      body: map["body"] || "",
      tags: map["tags"] || [],
      links: decode_links(map["links"]),
      created: map["created"] || "",
      modified: map["modified"] || "",
      created_by: map["created_by"] || "",
      modified_by: map["modified_by"] || "",
      archived: map["archived"] == true
    }
  end

  defp decode_note(_), do: nil

  defp decode_links(nil), do: []
  defp decode_links(links) when is_list(links) do
    Enum.map(links, fn
      %{"target" => target, "relation" => relation} ->
        %{target: target, relation: relation}
      %{"target" => target} ->
        %{target: target, relation: "related"}
      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end
  defp decode_links(_), do: []
end
