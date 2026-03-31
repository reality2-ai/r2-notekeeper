defmodule Notekeeper.IdGenerator do
  @moduledoc """
  Generates unique identifiers for notes and events.

  Format: `note-<8hex>` for notes, `evt-<8hex>` for events.
  Uses `:crypto.strong_rand_bytes/1` for randomness.
  """

  @doc "Generate a note ID: `note-<8hex>`."
  @spec note_id() :: String.t()
  def note_id, do: "note-" <> random_hex(4)

  @doc "Generate an event ID: `evt-<8hex>`."
  @spec event_id() :: String.t()
  def event_id, do: "evt-" <> random_hex(4)

  defp random_hex(bytes) do
    :crypto.strong_rand_bytes(bytes) |> Base.encode16(case: :lower)
  end
end
