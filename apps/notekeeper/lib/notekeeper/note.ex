defmodule Notekeeper.Note do
  @moduledoc """
  A note — the materialised state of a note entity.

  Notes are Markdown documents with tags, links, and metadata.
  The Note struct represents the current state; the full history
  lives in the event log.
  """

  @derive Jason.Encoder
  defstruct [
    :id,
    :title,
    :body,
    :tags,
    :links,
    :created,
    :modified,
    :created_by,
    :modified_by,
    :archived
  ]

  @type link :: %{target: String.t(), relation: String.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          body: String.t(),
          tags: [String.t()],
          links: [link()],
          created: String.t(),
          modified: String.t(),
          created_by: String.t(),
          modified_by: String.t(),
          archived: boolean()
        }

  @doc "Create a new note from a create event's data."
  @spec new(String.t(), map(), String.t(), String.t()) :: t()
  def new(id, data, device, timestamp) do
    %__MODULE__{
      id: id,
      title: Map.get(data, "title", ""),
      body: Map.get(data, "body", ""),
      tags: Map.get(data, "tags", []),
      links: [],
      created: timestamp,
      modified: timestamp,
      created_by: device,
      modified_by: device,
      archived: false
    }
  end
end
