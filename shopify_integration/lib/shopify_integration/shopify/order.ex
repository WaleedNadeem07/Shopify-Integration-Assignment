defmodule ShopifyIntegration.Shopify.Order do
  use Ecto.Schema
  import Ecto.Changeset

  schema "shopify_orders" do
    field :shopify_order_id, :string
    field :shop_domain, :string
    field :customer_name, :string
    field :total_price, :decimal
    field :currency, :string
    field :order_status, :string

    timestamps()
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [:shopify_order_id, :shop_domain, :customer_name, :total_price, :currency, :order_status])
    |> validate_required([:shopify_order_id, :shop_domain])
    |> unique_constraint(:shopify_order_id)
  end
end
