import Config

config :notekeeper,
  data_dir: "/tmp/nk_test",
  device_id: "test-device",
  start_store: false

config :notekeeper_web, NotekeeperWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: String.duplicate("test_secret_key_", 4),
  server: false
