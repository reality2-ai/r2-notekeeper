import Config

config :notekeeper_web, NotekeeperWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: false,
  debug_errors: true,
  secret_key_base: String.duplicate("dev_secret_key_base_", 4)
