defmodule NotekeeperWeb.PageController do
  use NotekeeperWeb, :controller

  def index(conn, _params) do
    html(conn, File.read!(Application.app_dir(:notekeeper_web, "priv/static/index.html")))
  end
end
