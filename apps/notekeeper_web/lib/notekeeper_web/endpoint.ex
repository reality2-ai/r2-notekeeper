defmodule NotekeeperWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :notekeeper_web

  plug Plug.Static,
    at: "/",
    from: {:notekeeper_web, "priv/static"},
    gzip: false,
    only: ~w(css js icons manifest.json sw.js favicon.ico)

  plug Plug.RequestId
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug NotekeeperWeb.Router
end
