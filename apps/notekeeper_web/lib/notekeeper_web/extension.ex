defmodule NotekeeperWeb.Extension do
  @behaviour R2.Web.Extension

  @impl true
  def static_dir do
    Application.app_dir(:notekeeper_web, "priv/static")
  end

  @impl true
  def graphql_schema, do: NotekeeperWeb.Schema

  @impl true
  def initial_state do
    %{
      notes: Notekeeper.NoteStore.list_notes(),
      tags: tags_payload()
    }
  end

  defp tags_payload do
    Notekeeper.NoteStore.get_tags()
    |> Enum.map(fn {tag, count} -> %{tag: tag, count: count} end)
    |> Enum.sort_by(& &1.tag)
  end
end
