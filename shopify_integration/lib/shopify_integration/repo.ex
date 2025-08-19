defmodule ShopifyIntegration.Repo do
  use Ecto.Repo,
    otp_app: :shopify_integration,
    adapter: Ecto.Adapters.Postgres
end
