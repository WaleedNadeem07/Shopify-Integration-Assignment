defmodule ShopifyIntegrationWeb.Router do
  use ShopifyIntegrationWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShopifyIntegrationWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ShopifyIntegrationWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Shopify OAuth routes
    get "/auth/shopify", AuthController, :shopify_oauth
    get "/auth/shopify/callback", AuthController, :shopify_callback

    # Dashboard routes
    get "/dashboard", DashboardController, :index
    get "/dashboard/shop/:shop_domain", DashboardController, :shop
    post "/dashboard/fetch_orders", DashboardController, :fetch_orders
  end

  # Other scopes may use custom stacks.
  # scope "/api", ShopifyIntegrationWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:shopify_integration, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShopifyIntegrationWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
