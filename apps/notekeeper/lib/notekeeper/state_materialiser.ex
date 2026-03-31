defmodule Notekeeper.StateMaterialiser do
  @moduledoc """
  Applies events to materialise the current note state.

  Pure functions — no side effects, no I/O. Given a notes map and an event,
  returns the updated notes map.

  Conflict resolution: last-write-wins by timestamp. Delete always wins
  over concurrent edits. Events for non-existent notes are silently
  ignored (except create). Duplicate creates are silently ignored.
  """

  alias Notekeeper.{Note, Event}

  @type notes_map :: %{String.t() => Note.t()}

  @doc "Apply a single event to the notes map."
  @spec apply_event(notes_map(), Event.t()) :: notes_map()
  def apply_event(notes, %Event{op: "create"} = event) do
    if Map.has_key?(notes, event.note) do
      # Duplicate create — silently ignore
      notes
    else
      note = Note.new(event.note, event.data, event.device, event.t)
      Map.put(notes, event.note, note)
    end
  end

  def apply_event(notes, %Event{op: "edit"} = event) do
    update_note(notes, event.note, fn note ->
      note
      |> maybe_update(:title, event.data["title"])
      |> maybe_update(:body, event.data["body"])
      |> Map.put(:modified, event.t)
      |> Map.put(:modified_by, event.device)
    end)
  end

  def apply_event(notes, %Event{op: "delete"} = event) do
    Map.delete(notes, event.note)
  end

  def apply_event(notes, %Event{op: "archive"} = event) do
    update_note(notes, event.note, fn note ->
      note
      |> Map.put(:archived, event.data["archived"] == true)
      |> Map.put(:modified, event.t)
      |> Map.put(:modified_by, event.device)
    end)
  end

  def apply_event(notes, %Event{op: "tag"} = event) do
    new_tags = event.data["tags"] || []

    update_note(notes, event.note, fn note ->
      merged = Enum.uniq(note.tags ++ new_tags)

      note
      |> Map.put(:tags, merged)
      |> Map.put(:modified, event.t)
      |> Map.put(:modified_by, event.device)
    end)
  end

  def apply_event(notes, %Event{op: "untag"} = event) do
    remove_tags = MapSet.new(event.data["tags"] || [])

    update_note(notes, event.note, fn note ->
      filtered = Enum.reject(note.tags, &MapSet.member?(remove_tags, &1))

      note
      |> Map.put(:tags, filtered)
      |> Map.put(:modified, event.t)
      |> Map.put(:modified_by, event.device)
    end)
  end

  def apply_event(notes, %Event{op: "link"} = event) do
    target = event.data["target"]
    relation = event.data["relation"] || "related"

    update_note(notes, event.note, fn note ->
      # Idempotent — don't add duplicate links
      existing = Enum.any?(note.links, fn l -> l.target == target && l.relation == relation end)

      if existing do
        note
      else
        link = %{target: target, relation: relation}

        note
        |> Map.put(:links, note.links ++ [link])
        |> Map.put(:modified, event.t)
        |> Map.put(:modified_by, event.device)
      end
    end)
  end

  def apply_event(notes, %Event{op: "unlink"} = event) do
    target = event.data["target"]

    update_note(notes, event.note, fn note ->
      filtered = Enum.reject(note.links, fn l -> l.target == target end)

      note
      |> Map.put(:links, filtered)
      |> Map.put(:modified, event.t)
      |> Map.put(:modified_by, event.device)
    end)
  end

  # Unknown op — silently ignore
  def apply_event(notes, _event), do: notes

  @doc "Apply a list of events to a notes map."
  @spec apply_events(notes_map(), [Event.t()]) :: notes_map()
  def apply_events(notes, events) do
    Enum.reduce(events, notes, &apply_event(&2, &1))
  end

  # Update a note if it exists, otherwise silently ignore.
  defp update_note(notes, note_id, update_fn) do
    case Map.get(notes, note_id) do
      nil -> notes
      note -> Map.put(notes, note_id, update_fn.(note))
    end
  end

  defp maybe_update(note, _field, nil), do: note
  defp maybe_update(note, field, value), do: Map.put(note, field, value)
end
