defmodule ShopifyIntegrationWeb.AuthController do
  use ShopifyIntegrationWeb, :controller

  alias ShopifyIntegration.Shopify.Client
  alias ShopifyIntegration.Shopify.Orders
  alias ShopifyIntegration.Repo
  alias ShopifyIntegration.Shopify.Shop

  @doc """
  Initiates the Shopify OAuth flow.
  Redirects the user to Shopify's authorization page.
  """
  def shopify_oauth(conn, params) do
    raw_shop = Map.get(params, "shop") || Application.get_env(:shopify_integration, :default_store_domain)
    shop_domain =
      case raw_shop do
        nil -> nil
        shop when is_binary(shop) ->
          trimmed = shop |> String.trim() |> String.downcase()
          cond do
            trimmed == "" -> nil
            String.ends_with?(trimmed, ".myshopify.com") or String.ends_with?(trimmed, ".myshopify.io") -> trimmed
            true -> trimmed <> ".myshopify.com"
          end
      end

    case shop_domain do
      nil ->
        conn
        |> put_flash(:error, "Missing shop domain. Please enter e.g. mystore.myshopify.com")
        |> redirect(to: ~p"/")

      _ ->
        case Client.validate_shop_domain(shop_domain) do
      {:ok, valid_domain} ->
        # Generate a random state parameter for CSRF protection
        state = :crypto.strong_rand_bytes(16) |> Base.encode16()

        # Store state and shop in session for validation later
        conn =
          conn
          |> put_session(:shopify_oauth_state, state)
          |> put_session(:shopify_shop_domain, valid_domain)

        # Build the OAuth authorization URL using the client module
        oauth_url = Client.build_oauth_url(valid_domain, state)

        # Redirect to Shopify's OAuth page
        redirect(conn, external: oauth_url)

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/")
        end
    end
  end

  @doc """
  Handles the OAuth callback from Shopify.
  Exchanges the authorization code for an access token.
  """
  def shopify_callback(conn, %{"code" => code, "shop" => shop_domain, "state" => state} = params) do
    # Validate state parameter to prevent CSRF attacks
    session_state = get_session(conn, :shopify_oauth_state)
    conn = delete_session(conn, :shopify_oauth_state)

    if is_nil(session_state) or session_state != state do
      conn
      |> put_flash(:error, "Invalid OAuth state. Please try again.")
      |> redirect(to: ~p"/")
    else
      # Verify HMAC signature from Shopify
      with :ok <- verify_shopify_hmac(params),
           {:ok, _} <- Client.validate_shop_domain(shop_domain) do
        # Exchange the authorization code for an access token
        case Client.exchange_code_for_token(shop_domain, code) do
          {:ok, %{"access_token" => access_token} = token_response} ->
            # Persist or update the shop with the access token
            upsert_shop(shop_domain, access_token, Map.get(token_response, "scope"))

            # Auto-fetch orders after successful authentication
            case Orders.fetch_and_store_orders(shop_domain, access_token) do
              {:ok, %{total_fetched: total, successful: successful, failed: failed}} ->
                conn
                |> put_flash(:info, "Connected to #{shop_domain}. Fetched #{total} orders (#{successful} stored, #{failed} failed).")
                |> redirect(to: ~p"/dashboard/shop/#{shop_domain}")

              {:error, reason} ->
                conn
                |> put_flash(:error, "Connected to #{shop_domain}, but failed to fetch orders: #{reason}")
                |> redirect(to: ~p"/dashboard/shop/#{shop_domain}")
            end

          {:error, err} ->
            conn
            |> put_flash(:error, "Failed to get access token: #{err}")
            |> redirect(to: ~p"/")
        end
      else
        {:error, msg} ->
          conn
          |> put_flash(:error, to_string(msg))
          |> redirect(to: ~p"/")
      end
    end
  end

  def shopify_callback(conn, _params) do
    # Handle error cases (missing code, shop, or state)
    conn
    |> put_flash(:error, "OAuth authentication failed. Please try again.")
    |> redirect(to: ~p"/")
  end

  # Private helpers
  defp upsert_shop(shop_domain, access_token, scope) do
    changes = %{shop_domain: shop_domain, access_token: access_token, scope: scope}

    case Repo.get_by(Shop, shop_domain: shop_domain) do
      nil ->
        %Shop{}
        |> Shop.changeset(changes)
        |> Repo.insert()

      shop ->
        shop
        |> Shop.changeset(changes)
        |> Repo.update()
    end
  end

  defp verify_shopify_hmac(params) do
    provided_hmac = Map.get(params, "hmac")

    if is_nil(provided_hmac) do
      {:error, "Missing HMAC in callback."}
    else
      secret =
        (Application.get_env(:shopify_integration, ShopifyIntegration.Shopify.Client)[:api_secret]
         || System.get_env("SHOPIFY_API_SECRET")
         || "")

      data =
        params
        |> Map.drop(["hmac", "signature"])
        |> Enum.map(fn {k, v} -> {k, to_string(v)} end)
        |> Enum.sort_by(fn {k, _v} -> k end)
        |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
        |> Enum.join("&")

      digest = :crypto.mac(:hmac, :sha256, secret, data) |> Base.encode16(case: :lower)

      if Plug.Crypto.secure_compare(digest, String.downcase(provided_hmac)) do
        :ok
      else
        {:error, "Invalid HMAC in callback."}
      end
    end
  end
end
