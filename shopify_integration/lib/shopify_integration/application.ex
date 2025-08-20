defmodule ShopifyIntegration.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting Shopify Integration application...")

    # Load environment variables from .env file
    case Dotenvy.source([".env", ".env.#{Mix.env()}", ".env.#{Mix.env()}.local"]) do
      {:ok, _} ->
        Logger.info("Environment variables loaded successfully")
      {:error, reason} ->
        Logger.warning("Failed to load some environment variables: #{inspect(reason)}")
    end

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

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("Shopify Integration application started successfully")
        {:ok, pid}
      {:error, reason} ->
        Logger.error("Failed to start Shopify Integration application: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Logger.info("Application configuration changed. Updating endpoint...")
    ShopifyIntegrationWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
