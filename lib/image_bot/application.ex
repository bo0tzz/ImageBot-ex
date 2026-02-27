defmodule ImageBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Cachex.Spec

  @impl true
  def start(_type, _args) do
    children = [
      {Cachex,
       [
         name: :search_cache,
         expiration: Cachex.Spec.expiration(interval: nil, default: 84600),
         limit: Cachex.Spec.limit(size: 5000)
       ]},
      Keys,
      ExGram,
      {ImageBot, [method: :polling, token: Application.fetch_env!(:image_bot, :bot_token)]},
      {TelemetryMetricsPrometheus.Core, metrics: ImageBot.Metrics.metrics()},
      {Bandit, plug: ImageBot.Metrics, port: Application.get_env(:image_bot, :metrics_port, 4000)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ImageBot.Application.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
