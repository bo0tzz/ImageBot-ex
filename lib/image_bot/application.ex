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
      Search.Keys,
      ExGram,
      {ImageBot, [method: :polling, token: Application.fetch_env!(:image_bot, :bot_token)]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ImageBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
