import Config

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE not set"

  config :notekeeper_web, NotekeeperWeb.Endpoint,
    secret_key_base: secret_key_base

  port = String.to_integer(System.get_env("PORT") || "4000")

  config :notekeeper_web, NotekeeperWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: port]
end

if data_dir = System.get_env("NK_DATA_DIR") do
  config :notekeeper, data_dir: data_dir
end

if device_id = System.get_env("NK_DEVICE_ID") do
  config :notekeeper, device_id: device_id
end
