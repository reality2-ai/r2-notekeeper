defmodule Notekeeper.NoteStoreTest do
  use ExUnit.Case, async: false

  alias Notekeeper.{NoteStore, Note}

  @data_dir "/tmp/nk_test_#{:rand.uniform(999999)}"

  setup do
    # Clean data directory
    File.rm_rf!(@data_dir)
    File.mkdir_p!(@data_dir)

    # Start the NoteStore with test data dir
    start_supervised!({NoteStore, [data_dir: @data_dir, device_id: "test-device"]})

    on_exit(fn -> File.rm_rf!(@data_dir) end)
    :ok
  end

  test "create a note" do
    {:ok, note} = NoteStore.create_note("Hello", "# First note", ["test"])
    assert note.title == "Hello"
    assert note.body == "# First note"
    assert note.tags == ["test"]
    assert String.starts_with?(note.id, "note-")
    assert note.created_by == "test-device"
    assert note.archived == false
  end

  test "list notes" do
    {:ok, _} = NoteStore.create_note("Note 1", "Body 1")
    {:ok, _} = NoteStore.create_note("Note 2", "Body 2")

    notes = NoteStore.list_notes()
    assert length(notes) == 2
  end

  test "get note by ID" do
    {:ok, note} = NoteStore.create_note("Findme", "Content")
    found = NoteStore.get_note(note.id)
    assert found.title == "Findme"
  end

  test "edit a note" do
    {:ok, note} = NoteStore.create_note("Original", "Original body")
    {:ok, updated} = NoteStore.edit_note(note.id, %{title: "Updated"})
    assert updated.title == "Updated"
    assert updated.body == "Original body"
  end

  test "edit non-existent note returns error" do
    assert {:error, :not_found} = NoteStore.edit_note("note-nonexistent", %{title: "X"})
  end

  test "delete a note" do
    {:ok, note} = NoteStore.create_note("Delete me", "Gone")
    :ok = NoteStore.delete_note(note.id)
    assert NoteStore.get_note(note.id) == nil
    assert NoteStore.list_notes() == []
  end

  test "archive and unarchive" do
    {:ok, note} = NoteStore.create_note("Archive test", "Body")

    {:ok, archived} = NoteStore.archive_note(note.id, true)
    assert archived.archived == true

    # Archived notes hidden by default
    assert NoteStore.list_notes() == []
    assert length(NoteStore.list_notes(include_archived: true)) == 1

    {:ok, unarchived} = NoteStore.archive_note(note.id, false)
    assert unarchived.archived == false
    assert length(NoteStore.list_notes()) == 1
  end

  test "tag and untag" do
    {:ok, note} = NoteStore.create_note("Tags", "Body", ["initial"])
    {:ok, tagged} = NoteStore.tag_note(note.id, ["added", "another"])
    assert Enum.sort(tagged.tags) == ["added", "another", "initial"]

    {:ok, untagged} = NoteStore.untag_note(note.id, ["initial"])
    assert Enum.sort(untagged.tags) == ["added", "another"]
  end

  test "tag deduplication" do
    {:ok, note} = NoteStore.create_note("Dedup", "Body", ["a"])
    {:ok, tagged} = NoteStore.tag_note(note.id, ["a", "b"])
    assert Enum.sort(tagged.tags) == ["a", "b"]
  end

  test "link and unlink" do
    {:ok, note1} = NoteStore.create_note("Source", "Body")
    {:ok, note2} = NoteStore.create_note("Target", "Body")

    {:ok, linked} = NoteStore.link_notes(note1.id, note2.id, "references")
    assert length(linked.links) == 1
    assert hd(linked.links).target == note2.id
    assert hd(linked.links).relation == "references"

    {:ok, unlinked} = NoteStore.unlink_notes(note1.id, note2.id)
    assert unlinked.links == []
  end

  test "link idempotency" do
    {:ok, note1} = NoteStore.create_note("A", "")
    {:ok, note2} = NoteStore.create_note("B", "")

    {:ok, _} = NoteStore.link_notes(note1.id, note2.id, "ref")
    {:ok, linked} = NoteStore.link_notes(note1.id, note2.id, "ref")
    assert length(linked.links) == 1
  end

  test "get_tags returns frequencies" do
    {:ok, _} = NoteStore.create_note("A", "", ["elixir", "r2"])
    {:ok, _} = NoteStore.create_note("B", "", ["elixir", "rust"])

    tags = NoteStore.get_tags()
    assert tags["elixir"] == 2
    assert tags["r2"] == 1
    assert tags["rust"] == 1
  end

  test "search by title and body" do
    {:ok, _} = NoteStore.create_note("Elixir Notes", "Some content")
    {:ok, _} = NoteStore.create_note("Rust Guide", "About memory safety")

    assert length(NoteStore.list_notes(search: "elixir")) == 1
    assert length(NoteStore.list_notes(search: "memory")) == 1
    assert length(NoteStore.list_notes(search: "nonexistent")) == 0
  end

  test "filter by tag" do
    {:ok, _} = NoteStore.create_note("A", "", ["alpha"])
    {:ok, _} = NoteStore.create_note("B", "", ["beta"])

    assert length(NoteStore.list_notes(tag: "alpha")) == 1
    assert length(NoteStore.list_notes(tag: "gamma")) == 0
  end

  test "event log persists to disk" do
    {:ok, _} = NoteStore.create_note("Persistent", "Survives restart")

    events_dir = Path.join(@data_dir, "events")
    files = File.ls!(events_dir)
    assert length(files) == 1
    assert hd(files) |> String.ends_with?(".jsonl")

    content = Path.join(events_dir, hd(files)) |> File.read!()
    assert String.contains?(content, "Persistent")
  end
end
