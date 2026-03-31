defmodule NotekeeperWeb.Router do
  use NotekeeperWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", NotekeeperWeb do
    pipe_through :browser
    get "/", PageController, :index
  end
end
