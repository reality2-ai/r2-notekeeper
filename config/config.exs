import Config

config :notekeeper,
  data_dir: System.get_env("NK_DATA_DIR", "data"),
  device_id: System.get_env("NK_DEVICE_ID", "dev-local")

config :notekeeper_web, NotekeeperWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [formats: [json: NotekeeperWeb.ErrorJSON]],
  pubsub_server: NotekeeperWeb.PubSub,
  adapter: Phoenix.Endpoint.Cowboy2Adapter

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
