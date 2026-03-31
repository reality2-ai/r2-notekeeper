defmodule Notekeeper.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # NoteStore will be added in Phase 2
    ]

    opts = [strategy: :one_for_one, name: Notekeeper.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
