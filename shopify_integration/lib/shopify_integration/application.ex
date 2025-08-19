defmodule ShopifyIntegration.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ShopifyIntegrationWeb.Telemetry,
      ShopifyIntegration.Repo,
      {DNSCluster, query: Application.get_env(:shopify_integration, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ShopifyIntegration.PubSub},
      # Start a worker by calling: ShopifyIntegration.Worker.start_link(arg)
      # {ShopifyIntegration.Worker, arg},
      # Start to serve requests, typically the last entry
      ShopifyIntegrationWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ShopifyIntegration.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ShopifyIntegrationWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
