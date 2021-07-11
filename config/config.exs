import Config

case Config.config_env() do
  :dev ->
    config :logger, level: :debug

  _ ->
    config :logger,
      level: :info,
      compile_time_purge_matching: [
        [application: :tesla]
      ]
end

config :tesla, adapter: Tesla.Adapter.Hackney
