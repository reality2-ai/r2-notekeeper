defmodule Notekeeper.NoteStore do
  @moduledoc """
  Event-sourced note store — the core sentant data model.

  Manages the in-memory note collection backed by a JSONL event log.
  On startup: loads the latest snapshot, replays events since the
  snapshot, and materialises the current state.

  All mutations generate events that are:
  1. Applied to in-memory state
  2. Appended to the event log (with fsync)
  3. Broadcast via Phoenix.PubSub (when available)
  """

  use GenServer

  alias Notekeeper.{Note, Event, EventLog, Snapshot, Index, IdGenerator, StateMaterialiser}

  @snapshot_interval :timer.minutes(5)

  # --- Public API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Create a new note. Returns `{:ok, note}` or `{:error, reason}`."
  @spec create_note(String.t(), String.t(), [String.t()]) :: {:ok, Note.t()} | {:error, term()}
  def create_note(title, body \\ "", tags \\ []) do
    GenServer.call(__MODULE__, {:create, title, body, tags})
  end

  @doc "Edit a note. Attrs: `%{title: ..., body: ...}` (partial update)."
  @spec edit_note(String.t(), map()) :: {:ok, Note.t()} | {:error, :not_found}
  def edit_note(note_id, attrs) do
    GenServer.call(__MODULE__, {:edit, note_id, attrs})
  end

  @doc "Delete a note permanently."
  @spec delete_note(String.t()) :: :ok
  def delete_note(note_id) do
    GenServer.call(__MODULE__, {:delete, note_id})
  end

  @doc "Archive or unarchive a note."
  @spec archive_note(String.t(), boolean()) :: {:ok, Note.t()} | {:error, :not_found}
  def archive_note(note_id, archived \\ true) do
    GenServer.call(__MODULE__, {:archive, note_id, archived})
  end

  @doc "Add tags to a note."
  @spec tag_note(String.t(), [String.t()]) :: {:ok, Note.t()} | {:error, :not_found}
  def tag_note(note_id, tags) do
    GenServer.call(__MODULE__, {:tag, note_id, tags})
  end

  @doc "Remove tags from a note."
  @spec untag_note(String.t(), [String.t()]) :: {:ok, Note.t()} | {:error, :not_found}
  def untag_note(note_id, tags) do
    GenServer.call(__MODULE__, {:untag, note_id, tags})
  end

  @doc "Link one note to another."
  @spec link_notes(String.t(), String.t(), String.t()) :: {:ok, Note.t()} | {:error, :not_found}
  def link_notes(from_id, to_id, relation \\ "related") do
    GenServer.call(__MODULE__, {:link, from_id, to_id, relation})
  end

  @doc "Remove a link from one note to another."
  @spec unlink_notes(String.t(), String.t()) :: {:ok, Note.t()} | {:error, :not_found}
  def unlink_notes(from_id, to_id) do
    GenServer.call(__MODULE__, {:unlink, from_id, to_id})
  end

  @doc "Get a note by ID."
  @spec get_note(String.t()) :: Note.t() | nil
  def get_note(note_id) do
    GenServer.call(__MODULE__, {:get, note_id})
  end

  @doc "List all notes, optionally filtered."
  @spec list_notes(keyword()) :: [Note.t()]
  def list_notes(opts \\ []) do
    GenServer.call(__MODULE__, {:list, opts})
  end

  @doc "Get tag counts."
  @spec get_tags() :: %{String.t() => non_neg_integer()}
  def get_tags do
    GenServer.call(__MODULE__, :tags)
  end

  @doc "Apply a remote event (from sync). Returns :ok."
  @spec apply_remote_event(Event.t()) :: :ok
  def apply_remote_event(%Event{} = event) do
    GenServer.call(__MODULE__, {:remote_event, event})
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    data_dir = Keyword.get(opts, :data_dir, Application.get_env(:notekeeper, :data_dir, "data"))
    device_id = Keyword.get(opts, :device_id, Application.get_env(:notekeeper, :device_id, "dev-local"))

    # Ensure directories exist
    for subdir <- ["events", "state", "index"] do
      File.mkdir_p!(Path.join(data_dir, subdir))
    end

    # Load snapshot + replay events
    {notes, seen_ids} = load_state(data_dir)

    # Schedule periodic snapshot
    Process.send_after(self(), :snapshot, @snapshot_interval)

    {:ok,
     %{
       notes: notes,
       data_dir: data_dir,
       device_id: device_id,
       dirty: false,
       seen_event_ids: seen_ids
     }}
  end

  @impl true
  def handle_call({:create, title, body, tags}, _from, state) do
    note_id = IdGenerator.note_id()
    event = Event.new_create(note_id, title, body, tags, state.device_id)
    {new_state, note} = apply_and_persist(state, event)
    {:reply, {:ok, note}, new_state}
  end

  def handle_call({:edit, note_id, attrs}, _from, state) do
    if Map.has_key?(state.notes, note_id) do
      event = Event.new_edit(note_id, attrs, state.device_id)
      {new_state, note} = apply_and_persist(state, event)
      {:reply, {:ok, note}, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:delete, note_id}, _from, state) do
    event = Event.new_delete(note_id, state.device_id)
    {new_state, _} = apply_and_persist(state, event)
    {:reply, :ok, new_state}
  end

  def handle_call({:archive, note_id, archived}, _from, state) do
    if Map.has_key?(state.notes, note_id) do
      event = Event.new_archive(note_id, archived, state.device_id)
      {new_state, note} = apply_and_persist(state, event)
      {:reply, {:ok, note}, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:tag, note_id, tags}, _from, state) do
    if Map.has_key?(state.notes, note_id) do
      event = Event.new_tag(note_id, tags, state.device_id)
      {new_state, note} = apply_and_persist(state, event)
      {:reply, {:ok, note}, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:untag, note_id, tags}, _from, state) do
    if Map.has_key?(state.notes, note_id) do
      event = Event.new_untag(note_id, tags, state.device_id)
      {new_state, note} = apply_and_persist(state, event)
      {:reply, {:ok, note}, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:link, from_id, to_id, relation}, _from, state) do
    if Map.has_key?(state.notes, from_id) do
      event = Event.new_link(from_id, to_id, relation, state.device_id)
      {new_state, note} = apply_and_persist(state, event)
      {:reply, {:ok, note}, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:unlink, from_id, to_id}, _from, state) do
    if Map.has_key?(state.notes, from_id) do
      event = Event.new_unlink(from_id, to_id, state.device_id)
      {new_state, note} = apply_and_persist(state, event)
      {:reply, {:ok, note}, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:get, note_id}, _from, state) do
    {:reply, Map.get(state.notes, note_id), state}
  end

  def handle_call({:list, opts}, _from, state) do
    notes = Map.values(state.notes)

    notes =
      unless Keyword.get(opts, :include_archived, false) do
        Enum.reject(notes, & &1.archived)
      else
        notes
      end

    notes =
      case Keyword.get(opts, :tag) do
        nil -> notes
        tag -> Enum.filter(notes, fn n -> tag in n.tags end)
      end

    notes =
      case Keyword.get(opts, :search) do
        nil ->
          notes

        query ->
          q = String.downcase(query)

          Enum.filter(notes, fn n ->
            String.contains?(String.downcase(n.title), q) ||
              String.contains?(String.downcase(n.body), q)
          end)
      end

    # Sort by modified descending
    notes = Enum.sort_by(notes, & &1.modified, :desc)
    {:reply, notes, state}
  end

  def handle_call(:tags, _from, state) do
    tags =
      state.notes
      |> Map.values()
      |> Enum.reject(& &1.archived)
      |> Enum.flat_map(& &1.tags)
      |> Enum.frequencies()

    {:reply, tags, state}
  end

  def handle_call({:remote_event, event}, _from, state) do
    if MapSet.member?(state.seen_event_ids, event.id) do
      # Duplicate — already applied
      {:reply, :ok, state}
    else
      # Apply and persist (but don't re-broadcast as "local")
      notes = StateMaterialiser.apply_event(state.notes, event)
      EventLog.append(state.data_dir, event)
      seen = MapSet.put(state.seen_event_ids, event.id)
      broadcast_event(event)
      {:reply, :ok, %{state | notes: notes, seen_event_ids: seen, dirty: true}}
    end
  end

  @impl true
  def handle_info(:snapshot, state) do
    if state.dirty do
      Snapshot.save(state.data_dir, state.notes)
      {by_tag, by_date} = Index.rebuild(state.notes)
      Index.save(state.data_dir, by_tag, by_date)
    end

    Process.send_after(self(), :snapshot, @snapshot_interval)
    {:noreply, %{state | dirty: false}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # --- Private ---

  defp load_state(data_dir) do
    {notes, since} =
      case Snapshot.load(data_dir) do
        {notes_map, timestamp} -> {notes_map, timestamp}
        :none -> {%{}, nil}
      end

    events = EventLog.replay(data_dir, since)
    notes = StateMaterialiser.apply_events(notes, events)
    seen_ids = events |> Enum.map(& &1.id) |> MapSet.new()
    {notes, seen_ids}
  end

  defp apply_and_persist(state, event) do
    notes = StateMaterialiser.apply_event(state.notes, event)
    EventLog.append(state.data_dir, event)
    seen = MapSet.put(state.seen_event_ids, event.id)
    broadcast_event(event)
    note = Map.get(notes, event.note)
    {%{state | notes: notes, seen_event_ids: seen, dirty: true}, note}
  end

  defp broadcast_event(event) do
    # Broadcast via PubSub if available (Phase 3 will subscribe)
    if Process.whereis(NotekeeperWeb.PubSub) do
      Phoenix.PubSub.broadcast(NotekeeperWeb.PubSub, "notekeeper:events", {:note_event, event})
    end
  end
end
