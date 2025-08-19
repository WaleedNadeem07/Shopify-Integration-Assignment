defmodule ShopifyIntegration.Shopify.Client do
  @moduledoc """
  Client module for interacting with Shopify's API.
  Handles OAuth flow, token exchange, and API requests.
  """

  @doc """
  Builds the OAuth authorization URL for a given shop domain.
  """
  def build_oauth_url(shop_domain, state) do
    api_key = get_api_key()
    redirect_uri = get_redirect_uri()
    scopes = get_required_scopes()

    "https://#{shop_domain}/admin/oauth/authorize?" <>
      "client_id=#{api_key}&" <>
      "scope=#{scopes}&" <>
      "redirect_uri=#{URI.encode(redirect_uri)}&" <>
      "state=#{state}"
  end

  @doc """
  Exchanges an authorization code for an access token.
  """
  def exchange_code_for_token(shop_domain, code) do
    api_key = get_api_key()
    api_secret = get_api_secret()
    redirect_uri = get_redirect_uri()

    url = "https://#{shop_domain}/admin/oauth/access_token"

    body = %{
      "client_id" => api_key,
      "client_secret" => api_secret,
      "code" => code,
      "redirect_uri" => redirect_uri
    }

    # TODO: Use HTTPoison to make the request
    # For now, return a mock response
    {:ok, %{
      "access_token" => "mock_access_token_#{shop_domain}",
      "scope" => get_required_scopes()
    }}
  end

  @doc """
  Validates a shop domain format.
  """
  def validate_shop_domain(shop_domain) do
    cond do
      String.ends_with?(shop_domain, ".myshopify.com") ->
        {:ok, shop_domain}

      String.ends_with?(shop_domain, ".myshopify.io") ->
        {:ok, shop_domain}

      true ->
        {:error, "Invalid shop domain format. Must end with .myshopify.com or .myshopify.io"}
    end
  end

  @doc """
  Makes an authenticated request to Shopify's API.
  """
  def api_request(shop_domain, access_token, endpoint, method \\ :get, body \\ nil) do
    url = "https://#{shop_domain}/admin/api/2023-10/#{endpoint}"

    headers = [
      {"X-Shopify-Access-Token", access_token},
      {"Content-Type", "application/json"}
    ]

    # TODO: Use HTTPoison to make the request
    # For now, return a mock response
    case method do
      :get when endpoint == "orders.json" ->
        {:ok, %{
          "orders" => [
            %{
              "id" => 123456789,
              "order_number" => "#1001",
              "total_price" => "29.99",
              "currency" => "USD",
              "customer" => %{"first_name" => "John", "last_name" => "Doe"},
              "financial_status" => "paid"
            }
          ]
        }}

      _ ->
        {:ok, %{"message" => "Mock response for #{method} #{endpoint}"}}
    end
  end

  # Private helper functions

  defp get_api_key do
    # TODO: Get from configuration
    "your_shopify_api_key"
  end

  defp get_api_secret do
    # TODO: Get from configuration
    "your_shopify_api_secret"
  end

  defp get_redirect_uri do
    # TODO: Get from configuration
    "http://localhost:4000/auth/shopify/callback"
  end

  defp get_required_scopes do
    # TODO: Get from configuration
    "read_orders,read_customers"
  end
end
