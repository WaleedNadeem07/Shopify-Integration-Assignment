defmodule ShopifyIntegration.Shopify.Shop do
  use Ecto.Schema
  import Ecto.Changeset

  schema "shops" do
    field :shop_domain, :string
    field :access_token, :string
    field :scope, :string

    timestamps()
  end

  @doc false
  def changeset(shop, attrs) do
    shop
    |> cast(attrs, [:shop_domain, :access_token, :scope])
    |> validate_required([:shop_domain, :access_token])
    |> unique_constraint(:shop_domain)
  end
end


