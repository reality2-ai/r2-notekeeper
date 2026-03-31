import Config

config :notekeeper_web, NotekeeperWeb.Endpoint,
  url: [host: "localhost", port: 443],
  cache_static_manifest: "priv/static/cache_manifest.json"
