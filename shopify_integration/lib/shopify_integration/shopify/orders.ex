defmodule ShopifyIntegration.Shopify.Orders do
  @moduledoc """
  Service module for fetching and managing Shopify orders.
  Handles API calls, data transformation, and database operations.
  """

  alias ShopifyIntegration.Shopify.{Client, Order}
  alias ShopifyIntegration.Repo
  import Ecto.Query

  @doc """
  Fetches orders from a Shopify store and stores them in the database.
  """
  def fetch_and_store_orders(shop_domain, access_token) do
    # Fetch up to 250 orders across any status
    case Client.api_request(shop_domain, access_token, "orders.json?status=any&limit=250") do
      {:ok, %{"orders" => orders}} ->
        # Transform and store each order
        results = Enum.map(orders, &store_order(&1, shop_domain))

        # Count successful and failed operations
        successful = Enum.count(results, &match?({:ok, _}, &1))
        failed = Enum.count(results, &match?({:error, _}, &1))

        {:ok, %{
          total_fetched: length(orders),
          successful: successful,
          failed: failed,
          results: results
        }}

      {:error, reason} ->
        {:error, "Failed to fetch orders: #{reason}"}

      _ ->
        {:error, "Unexpected response from Shopify API"}
    end
  end

  @doc """
  Stores a single order in the database.
  """
  def store_order(order_data, shop_domain) do
    # Transform Shopify order data to our schema
    order_attrs = %{
      shopify_order_id: to_string(order_data["id"]),
      shop_domain: shop_domain,
      customer_name: build_customer_name(order_data["customer"]),
      total_price: parse_decimal(order_data["total_price"]),
      currency: order_data["currency"],
      order_status: order_data["financial_status"] || "unknown"
    }

    # Check if order already exists
    case Repo.get_by(Order, shopify_order_id: order_attrs.shopify_order_id) do
      nil ->
        # Create new order
        %Order{}
        |> Order.changeset(order_attrs)
        |> Repo.insert()

      existing_order ->
        # Update existing order
        existing_order
        |> Order.changeset(order_attrs)
        |> Repo.update()
    end
  end

  @doc """
  Retrieves all orders for a specific shop from the database.
  """
  def get_shop_orders(shop_domain) do
    Order
    |> where([o], o.shop_domain == ^shop_domain)
    |> order_by([o], [desc: o.inserted_at])
    |> Repo.all()
  end

  @doc """
  Retrieves all orders from the database.
  """
  def get_all_orders do
    Order
    |> order_by([o], [desc: o.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets order statistics for a shop.
  """
  def get_shop_stats(shop_domain) do
    # Get basic stats
    stats_query = from o in Order,
      where: o.shop_domain == ^shop_domain,
      select: %{
        total_orders: count(o.id),
        total_revenue: sum(o.total_price)
      }

    # Get currency (most common one)
    currency_query = from o in Order,
      where: o.shop_domain == ^shop_domain and not is_nil(o.currency),
      group_by: o.currency,
      order_by: [desc: count(o.id)],
      limit: 1,
      select: o.currency

    case {Repo.one(stats_query), Repo.one(currency_query)} do
      {%{total_orders: total, total_revenue: revenue}, currency} ->
        {:ok, %{
          total_orders: total,
          total_revenue: revenue || Decimal.new(0),
          currency: currency || "USD"
        }}

      {nil, _} ->
        {:ok, %{total_orders: 0, total_revenue: Decimal.new(0), currency: "USD"}}
    end
  end

  # Private helper functions

  defp build_customer_name(customer) when is_map(customer) do
    first_name = customer["first_name"] || ""
    last_name = customer["last_name"] || ""

    case {first_name, last_name} do
      {"", ""} -> "Unknown Customer"
      {first, ""} -> first
      {"", last} -> last
      {first, last} -> "#{first} #{last}"
    end
  end

  defp build_customer_name(_), do: "Unknown Customer"

  defp parse_decimal(price) when is_binary(price) do
    trimmed = String.trim(price)
    case trimmed do
      "" -> Decimal.new(0)
      _ ->
        case Decimal.parse(trimmed) do
          {decimal, _rest} -> decimal
          :error -> Decimal.new(0)
        end
    end
  end

  defp parse_decimal(price) when is_integer(price), do: Decimal.new(price)
  defp parse_decimal(price) when is_float(price), do: Decimal.from_float(price)
  defp parse_decimal(nil), do: Decimal.new(0)
  defp parse_decimal(_), do: Decimal.new(0)
end
