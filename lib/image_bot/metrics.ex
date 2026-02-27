defmodule ImageBot.Metrics do
  use Plug.Router
  import Telemetry.Metrics

  plug :match
  plug :dispatch

  get "/metrics" do
    send_resp(conn, 200, TelemetryMetricsPrometheus.Core.scrape())
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  def metrics do
    [
      counter("image_bot.command.count",
        event_name: [:image_bot, :command],
        measurement: :count,
        tags: [:command]
      ),
      counter("image_bot.inline_query.count",
        event_name: [:image_bot, :inline_query],
        measurement: :count
      ),
      counter("image_bot.photo_retry.count",
        event_name: [:image_bot, :photo_retry],
        measurement: :count
      ),
      counter("image_bot.cache_hit.count",
        event_name: [:image_bot, :cache_hit],
        measurement: :count
      ),
      counter("image_bot.cache_miss.count",
        event_name: [:image_bot, :cache_miss],
        measurement: :count
      ),
      counter("image_bot.search.stop.count",
        event_name: [:image_bot, :search, :stop],
        measurement: fn _ -> 1 end,
        tags: [:status]
      ),
      distribution("image_bot.search.stop.duration",
        event_name: [:image_bot, :search, :stop],
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 25, 50, 100, 250, 500, 1000, 2500, 5000]]
      ),
      counter("image_bot.google_api_call.stop.count",
        event_name: [:image_bot, :google_api_call, :stop],
        measurement: fn _ -> 1 end,
        tags: [:status]
      ),
      distribution("image_bot.google_api_call.stop.duration",
        event_name: [:image_bot, :google_api_call, :stop],
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 25, 50, 100, 250, 500, 1000, 2500, 5000]]
      ),
      counter("image_bot.key_added.count",
        event_name: [:image_bot, :key_added],
        measurement: :count,
        tags: [:type]
      ),
      counter("image_bot.key_bad.count",
        event_name: [:image_bot, :key_bad],
        measurement: :count
      ),
      counter("image_bot.key_limited.count",
        event_name: [:image_bot, :key_limited],
        measurement: :count
      ),
      last_value("image_bot.key_active_count.count",
        event_name: [:image_bot, :key_active_count],
        measurement: :count
      )
    ]
  end
end
