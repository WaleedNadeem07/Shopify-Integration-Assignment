defmodule ShopifyIntegration.Repo.Migrations.CreateShopifyOrders do
  use Ecto.Migration

  def change do
    create table(:shopify_orders) do
      add :shopify_order_id, :string, null: false
      add :shop_domain, :string, null: false
      add :customer_name, :string
      add :total_price, :decimal, precision: 10, scale: 2
      add :currency, :string
      add :order_status, :string
      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    # Add indexes for better query performance
    create unique_index(:shopify_orders, [:shopify_order_id])
    create index(:shopify_orders, [:shop_domain])
    create index(:shopify_orders, [:order_status])
  end
end
