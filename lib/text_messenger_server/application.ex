defmodule TextMessengerServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TextMessengerServerWeb.Telemetry,
      TextMessengerServer.Repo,
      {DNSCluster, query: Application.get_env(:text_messenger_server, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TextMessengerServer.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: TextMessengerServer.Finch},
      # Start a worker by calling: TextMessengerServer.Worker.start_link(arg)
      # {TextMessengerServer.Worker, arg},
      # Start to serve requests, typically the last entry
      TextMessengerServerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TextMessengerServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TextMessengerServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
