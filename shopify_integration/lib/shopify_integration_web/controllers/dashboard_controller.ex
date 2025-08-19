defmodule ShopifyIntegrationWeb.DashboardController do
  use ShopifyIntegrationWeb, :controller

  alias ShopifyIntegration.Shopify.Orders
  alias ShopifyIntegration.Shopify.Shop
  alias ShopifyIntegration.Repo

  @doc """
  Shows the main dashboard with orders and statistics.
  """
  def index(conn, _params) do
    # Get all orders for display
    orders = Orders.get_all_orders()

    # Get overall statistics
    stats = get_overall_stats(orders)

    render(conn, :index, orders: orders, stats: stats)
  end

  @doc """
  Shows orders for a specific shop.
  """
  def shop(conn, %{"shop_domain" => shop_domain}) do
    # Get orders for this specific shop
    orders = Orders.get_shop_orders(shop_domain)

    # Get shop-specific statistics
    case Orders.get_shop_stats(shop_domain) do
      {:ok, stats} ->
        render(conn, :shop, orders: orders, stats: stats, shop_domain: shop_domain)

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to load shop statistics")
        |> redirect(to: ~p"/dashboard")
    end
  end

  @doc """
  Triggers fetching of orders from a Shopify store.
  """
  def fetch_orders(conn, %{"shop_domain" => shop_domain, "access_token" => access_token}) do
    # If access_token not provided, try to retrieve from stored shop
    token =
      case access_token do
        token when is_binary(token) ->
          trimmed = String.trim(token)
          if trimmed == "", do: nil, else: trimmed
        _ ->
          case Repo.get_by(Shop, shop_domain: shop_domain) do
            %Shop{access_token: stored} -> stored
            _ -> nil
          end
      end

    case token do
      nil ->
        conn
        |> put_flash(:error, "Missing access token and none stored for this shop.")
        |> redirect(to: ~p"/dashboard/shop/#{shop_domain}")

      token ->
        case Orders.fetch_and_store_orders(shop_domain, token) do
      {:ok, %{total_fetched: total, successful: successful, failed: failed}} ->
        message = "Successfully fetched #{total} orders. #{successful} stored, #{failed} failed."

        conn
        |> put_flash(:info, message)
        |> redirect(to: ~p"/dashboard/shop/#{shop_domain}")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to fetch orders: #{reason}")
        |> redirect(to: ~p"/dashboard/shop/#{shop_domain}")
        end
    end
  end

  def fetch_orders(conn, _params) do
    conn
    |> put_flash(:error, "Missing shop domain or access token")
    |> redirect(to: ~p"/dashboard")
  end

  # Private helper functions

  defp get_overall_stats(orders) do
    total_orders = length(orders)

    total_revenue = orders
    |> Enum.map(& &1.total_price)
    |> Enum.reduce(Decimal.new(0), fn price, acc -> Decimal.add(acc, price) end)

    shop_count = orders
    |> Enum.map(& &1.shop_domain)
    |> Enum.uniq()
    |> length()

    %{
      total_orders: total_orders,
      total_revenue: total_revenue,
      shop_count: shop_count
    }
  end
end
