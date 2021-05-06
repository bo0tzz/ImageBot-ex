defmodule ImageBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExGram,
      {ImageBot, [method: :polling, token: Application.fetch_env!(:image_bot, :token)]},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ImageBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
