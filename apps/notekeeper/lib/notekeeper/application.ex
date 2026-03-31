defmodule Notekeeper.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:notekeeper, :start_store, true) do
        data_dir = Application.get_env(:notekeeper, :data_dir, "data")
        device_id = Application.get_env(:notekeeper, :device_id, "dev-local")
        [{Notekeeper.NoteStore, [data_dir: data_dir, device_id: device_id]}]
      else
        []
      end

    opts = [strategy: :one_for_one, name: Notekeeper.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
