defmodule Notekeeper.Event do
  @moduledoc """
  An epistemic event — something that happened to a note.

  Events are the source of truth. Current note state is derived by
  replaying events. Each event is a single JSON line in the event log.

  Operations: create, edit, delete, archive, tag, untag, link, unlink.
  """

  @derive Jason.Encoder
  defstruct [:id, :t, :op, :device, :note, :data]

  @type t :: %__MODULE__{
          id: String.t(),
          t: String.t(),
          op: String.t(),
          device: String.t(),
          note: String.t(),
          data: map()
        }

  alias Notekeeper.IdGenerator

  @doc "Build a create event."
  @spec new_create(String.t(), String.t(), String.t(), [String.t()], String.t()) :: t()
  def new_create(note_id, title, body, tags \\ [], device) do
    %__MODULE__{
      id: IdGenerator.event_id(),
      t: now(),
      op: "create",
      device: device,
      note: note_id,
      data: %{"title" => title, "body" => body, "tags" => tags}
    }
  end

  @doc "Build an edit event. At least one of title or body must be provided."
  @spec new_edit(String.t(), map(), String.t()) :: t()
  def new_edit(note_id, attrs, device) do
    data =
      %{}
      |> maybe_put("title", Map.get(attrs, :title) || Map.get(attrs, "title"))
      |> maybe_put("body", Map.get(attrs, :body) || Map.get(attrs, "body"))

    %__MODULE__{
      id: IdGenerator.event_id(),
      t: now(),
      op: "edit",
      device: device,
      note: note_id,
      data: data
    }
  end

  @doc "Build a delete event."
  @spec new_delete(String.t(), String.t()) :: t()
  def new_delete(note_id, device) do
    %__MODULE__{
      id: IdGenerator.event_id(),
      t: now(),
      op: "delete",
      device: device,
      note: note_id,
      data: %{}
    }
  end

  @doc "Build an archive/unarchive event."
  @spec new_archive(String.t(), boolean(), String.t()) :: t()
  def new_archive(note_id, archived, device) do
    %__MODULE__{
      id: IdGenerator.event_id(),
      t: now(),
      op: "archive",
      device: device,
      note: note_id,
      data: %{"archived" => archived}
    }
  end

  @doc "Build a tag event (add tags)."
  @spec new_tag(String.t(), [String.t()], String.t()) :: t()
  def new_tag(note_id, tags, device) do
    %__MODULE__{
      id: IdGenerator.event_id(),
      t: now(),
      op: "tag",
      device: device,
      note: note_id,
      data: %{"tags" => tags}
    }
  end

  @doc "Build an untag event (remove tags)."
  @spec new_untag(String.t(), [String.t()], String.t()) :: t()
  def new_untag(note_id, tags, device) do
    %__MODULE__{
      id: IdGenerator.event_id(),
      t: now(),
      op: "untag",
      device: device,
      note: note_id,
      data: %{"tags" => tags}
    }
  end

  @doc "Build a link event."
  @spec new_link(String.t(), String.t(), String.t(), String.t()) :: t()
  def new_link(note_id, target_id, relation, device) do
    %__MODULE__{
      id: IdGenerator.event_id(),
      t: now(),
      op: "link",
      device: device,
      note: note_id,
      data: %{"target" => target_id, "relation" => relation}
    }
  end

  @doc "Build an unlink event."
  @spec new_unlink(String.t(), String.t(), String.t()) :: t()
  def new_unlink(note_id, target_id, device) do
    %__MODULE__{
      id: IdGenerator.event_id(),
      t: now(),
      op: "unlink",
      device: device,
      note: note_id,
      data: %{"target" => target_id}
    }
  end

  @doc "Encode event as a JSON string (one line, no trailing newline)."
  @spec to_json(t()) :: String.t()
  def to_json(%__MODULE__{} = event) do
    Jason.encode!(event)
  end

  @doc "Decode event from a JSON string."
  @spec from_json(String.t()) :: {:ok, t()} | {:error, term()}
  def from_json(json) do
    case Jason.decode(json) do
      {:ok, map} ->
        {:ok,
         %__MODULE__{
           id: map["id"],
           t: map["t"],
           op: map["op"],
           device: map["device"],
           note: map["note"],
           data: map["data"] || %{}
         }}

      error ->
        error
    end
  end

  defp now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
