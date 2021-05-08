import Config

config :logger, level: :info

if Config.config_env() == :dev do
  DotenvParser.load_file(".env")
  config :logger, level: :debug
end

config :image_bot,
  bot_token: System.fetch_env!("BOT_TOKEN"),
  key_db_path: System.get_env("KEY_DB_PATH", "./keys.db"),
  feedback_chat: System.get_env("FEEDBACK_CHAT", "97824825")
