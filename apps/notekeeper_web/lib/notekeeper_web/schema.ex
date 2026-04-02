defmodule NotekeeperWeb.Schema do
  use Absinthe.Schema

  import_types R2.GQL.Types
  import R2.GQL.Query

  alias Notekeeper.NoteStore

  object :note_link do
    field :target, non_null(:string)
    field :relation, non_null(:string)
  end

  object :note do
    field :id, non_null(:id)
    field :title, non_null(:string)
    field :body, non_null(:string)
    field :tags, non_null(list_of(non_null(:string)))
    field :links, non_null(list_of(non_null(:note_link)))
    field :created, non_null(:string)
    field :modified, non_null(:string)
    field :created_by, non_null(:string)
    field :modified_by, non_null(:string)
    field :archived, non_null(:boolean)
  end

  object :tag_count do
    field :tag, non_null(:string)
    field :count, non_null(:integer)
  end

  query do
    base_queries()

    field :notes, non_null(list_of(non_null(:note))) do
      arg :search, :string
      arg :tag, :string
      arg :include_archived, :boolean

      resolve(fn args, _ ->
        opts =
          []
          |> maybe_put(:search, args[:search])
          |> maybe_put(:tag, args[:tag])
          |> maybe_put(:include_archived, args[:include_archived] || false)

        {:ok, NoteStore.list_notes(opts)}
      end)
    end

    field :note, :note do
      arg :id, non_null(:id)
      resolve(fn %{id: id}, _ -> {:ok, NoteStore.get_note(id)} end)
    end

    field :tags, non_null(list_of(non_null(:tag_count))) do
      resolve(fn _, _ ->
        {:ok,
         NoteStore.get_tags()
         |> Enum.map(fn {tag, count} -> %{tag: tag, count: count} end)
         |> Enum.sort_by(& &1.tag)}
      end)
    end
  end

  mutation do
    field :create_note, non_null(:note) do
      arg :title, :string
      arg :body, :string
      arg :tags, list_of(non_null(:string))

      resolve(fn args, _ ->
        title = blank_to_default(args[:title], "Untitled")
        body = args[:body] || ""
        tags = args[:tags] || []

        NoteStore.create_note(title, body, tags)
      end)
    end

    field :update_note, :note do
      arg :id, non_null(:id)
      arg :title, :string
      arg :body, :string
      arg :archived, :boolean

      resolve(fn %{id: id} = args, _ ->
        attrs =
          %{}
          |> maybe_put_map(:title, blank_to_nil(args[:title]))
          |> maybe_put_map(:body, args[:body])

        with {:ok, note} <- maybe_edit(id, attrs),
             {:ok, note} <- maybe_archive(note, args) do
          {:ok, note}
        end
      end)
    end

    field :delete_note, non_null(:boolean) do
      arg :id, non_null(:id)

      resolve(fn %{id: id}, _ ->
        case NoteStore.get_note(id) do
          nil -> {:error, "not found"}
          _note ->
            :ok = NoteStore.delete_note(id)
            {:ok, true}
        end
      end)
    end

    field :add_tags, :note do
      arg :id, non_null(:id)
      arg :tags, non_null(list_of(non_null(:string)))
      resolve(fn %{id: id, tags: tags}, _ -> NoteStore.tag_note(id, tags) end)
    end

    field :remove_tags, :note do
      arg :id, non_null(:id)
      arg :tags, non_null(list_of(non_null(:string)))
      resolve(fn %{id: id, tags: tags}, _ -> NoteStore.untag_note(id, tags) end)
    end
  end

  defp maybe_put(keyword, _key, nil), do: keyword
  defp maybe_put(keyword, key, value), do: Keyword.put(keyword, key, value)

  defp maybe_put_map(map, _key, nil), do: map
  defp maybe_put_map(map, key, value), do: Map.put(map, key, value)

  defp maybe_edit(id, attrs) when map_size(attrs) == 0 do
    case NoteStore.get_note(id) do
      nil -> {:error, "not found"}
      note -> {:ok, note}
    end
  end

  defp maybe_edit(id, attrs), do: NoteStore.edit_note(id, attrs)

  defp maybe_archive({:error, _} = error, _args), do: error
  defp maybe_archive(note, %{archived: archived}) when is_boolean(archived), do: NoteStore.archive_note(note.id, archived)
  defp maybe_archive(note, _args), do: {:ok, note}

  defp blank_to_default(nil, default), do: default
  defp blank_to_default("", default), do: default
  defp blank_to_default(value, _default), do: value

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
