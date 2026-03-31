defmodule Notekeeper.EventLog do
  @moduledoc """
  Append-only JSONL event log with day-partitioned files.

  Events are stored as one JSON object per line in files named
  `YYYY-MM-DD.jsonl` under the `events/` directory. Files are
  append-only within a day and immutable after midnight.
  """

  alias Notekeeper.Event

  @doc "Append an event to today's log file. Syncs to disk."
  @spec append(String.t(), Event.t()) :: :ok | {:error, term()}
  def append(data_dir, %Event{} = event) do
    dir = Path.join(data_dir, "events")
    File.mkdir_p!(dir)

    path = Path.join(dir, today_filename())
    line = Event.to_json(event) <> "\n"

    case File.open(path, [:append, :sync]) do
      {:ok, file} ->
        IO.write(file, line)
        File.close(file)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Replay all events from the log, optionally starting from a given timestamp.

  Returns events sorted by (timestamp, device, id) for deterministic ordering.
  """
  @spec replay(String.t(), String.t() | nil) :: [Event.t()]
  def replay(data_dir, since \\ nil) do
    dir = Path.join(data_dir, "events")

    unless File.dir?(dir) do
      []
    else
      dir
      |> list_event_files()
      |> filter_files_since(since)
      |> Enum.flat_map(&read_events(Path.join(dir, &1)))
      |> filter_events_since(since)
      |> sort_events()
    end
  end

  @doc "List all event log filenames, sorted chronologically."
  @spec list_event_files(String.t()) :: [String.t()]
  def list_event_files(events_dir) do
    case File.ls(events_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".jsonl"))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  @doc "Return today's filename as `YYYY-MM-DD.jsonl`."
  @spec today_filename() :: String.t()
  def today_filename do
    Date.utc_today() |> Date.to_iso8601() |> Kernel.<>(".jsonl")
  end

  # Read all events from a single JSONL file.
  defp read_events(path) do
    case File.read(path) do
      {:ok, contents} ->
        contents
        |> String.split("\n", trim: true)
        |> Enum.flat_map(fn line ->
          case Event.from_json(line) do
            {:ok, event} -> [event]
            _ -> []
          end
        end)

      {:error, _} ->
        []
    end
  end

  # Filter filenames to only include those on or after the since date.
  defp filter_files_since(files, nil), do: files

  defp filter_files_since(files, since) do
    since_date = String.slice(since, 0, 10)

    Enum.filter(files, fn filename ->
      file_date = String.replace_suffix(filename, ".jsonl", "")
      file_date >= since_date
    end)
  end

  # Filter events to only include those after the since timestamp.
  defp filter_events_since(events, nil), do: events

  defp filter_events_since(events, since) do
    Enum.filter(events, fn event -> event.t > since end)
  end

  # Sort events by (timestamp, device, id) for deterministic ordering.
  defp sort_events(events) do
    Enum.sort_by(events, fn e -> {e.t, e.device, e.id} end)
  end
end
