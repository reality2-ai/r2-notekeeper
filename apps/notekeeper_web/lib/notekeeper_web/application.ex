defmodule NotekeeperWeb.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: NotekeeperWeb.PubSub},
      NotekeeperWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: NotekeeperWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
