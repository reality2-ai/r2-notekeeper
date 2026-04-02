defmodule NotekeeperWeb.SchemaTest do
  use ExUnit.Case, async: false

  @data_dir "/tmp/nk_web_schema_test"

  setup do
    File.rm_rf!(@data_dir)
    File.mkdir_p!(@data_dir)

    start_supervised!({Notekeeper.NoteStore, [data_dir: @data_dir, device_id: "schema-test-device"]})

    on_exit(fn -> File.rm_rf!(@data_dir) end)

    :ok
  end

  test "queries notes and tag counts" do
    {:ok, _} = Notekeeper.NoteStore.create_note("Alpha", "Body", ["r2"])

    assert {:ok, %{data: data}} =
             Absinthe.run(
               """
               {
                 notes { title body tags }
                 tags { tag count }
               }
               """,
               NotekeeperWeb.Schema
             )

    assert data["notes"] == [%{"title" => "Alpha", "body" => "Body", "tags" => ["r2"]}]
    assert data["tags"] == [%{"tag" => "r2", "count" => 1}]
  end

  test "creates and updates notes via mutations" do
    assert {:ok, %{data: %{"createNote" => created}}} =
             Absinthe.run(
               """
               mutation {
                 createNote(title: "Created", body: "Draft", tags: ["first"]) {
                   id
                   title
                   tags
                 }
               }
               """,
               NotekeeperWeb.Schema
             )

    assert created["title"] == "Created"
    assert created["tags"] == ["first"]

    assert {:ok, %{data: %{"updateNote" => updated}}} =
             Absinthe.run(
               """
               mutation($id: ID!) {
                 updateNote(id: $id, title: "Updated", archived: true) {
                   title
                   archived
                 }
               }
               """,
               NotekeeperWeb.Schema,
               variables: %{"id" => created["id"]}
             )

    assert updated["title"] == "Updated"
    assert updated["archived"] == true
  end
end
