import Config

if Config.config_env() == :dev do
  DotenvParser.load_file(".env")
end

config :image_bot,
  bot_token: System.fetch_env!("BOT_TOKEN"),
  key_db_path: System.get_env("KEY_DB_PATH", "./keys.db"),
  feedback_chat: System.get_env("FEEDBACK_CHAT", "-599173182"),
  metrics_port: System.get_env("METRICS_PORT", "4000") |> String.to_integer()
