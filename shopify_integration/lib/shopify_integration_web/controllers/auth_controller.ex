defmodule ShopifyIntegrationWeb.AuthController do
  use ShopifyIntegrationWeb, :controller

  @doc """
  Initiates the Shopify OAuth flow.
  Redirects the user to Shopify's authorization page.
  """
  def shopify_oauth(conn, _params) do
    # TODO: Get shop domain from user input or session
    shop_domain = "your-shop.myshopify.com"  # This will be configurable later

    # Build the OAuth authorization URL
    oauth_url = build_shopify_oauth_url(shop_domain)

    # Redirect to Shopify's OAuth page
    redirect(conn, external: oauth_url)
  end

  @doc """
  Handles the OAuth callback from Shopify.
  Exchanges the authorization code for an access token.
  """
  def shopify_callback(conn, %{"code" => code, "shop" => shop_domain, "state" => state}) do
    # TODO: Validate state parameter to prevent CSRF attacks
    # TODO: Exchange code for access token
    # TODO: Store access token securely

    # For now, just redirect to home with success message
    conn
    |> put_flash(:info, "Successfully connected to #{shop_domain}!")
    |> redirect(to: ~p"/")
  end

  def shopify_callback(conn, _params) do
    # Handle error cases (missing code, shop, or state)
    conn
    |> put_flash(:error, "OAuth authentication failed. Please try again.")
    |> redirect(to: ~p"/")
  end

  # Private helper functions

  defp build_shopify_oauth_url(shop_domain) do
    # TODO: Get these from configuration
    api_key = "your_shopify_api_key"
    redirect_uri = "http://localhost:4000/auth/shopify/callback"
    scopes = "read_orders,read_customers"

    # Generate a random state parameter for CSRF protection
    state = :crypto.strong_rand_bytes(16) |> Base.encode16()

    # Store state in session for validation later
    # TODO: Store state in session

    # Build the OAuth URL
    "https://#{shop_domain}/admin/oauth/authorize?" <>
      "client_id=#{api_key}&" <>
      "scope=#{scopes}&" <>
      "redirect_uri=#{URI.encode(redirect_uri)}&" <>
      "state=#{state}"
  end
end
