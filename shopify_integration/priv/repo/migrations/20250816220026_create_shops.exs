defmodule ShopifyIntegration.Repo.Migrations.CreateShops do
  use Ecto.Migration

  def change do
    create table(:shops) do
      add :shop_domain, :string, null: false
      add :access_token, :string, null: false
      add :scope, :string
      timestamps()
    end

    create unique_index(:shops, [:shop_domain])
  end
end


