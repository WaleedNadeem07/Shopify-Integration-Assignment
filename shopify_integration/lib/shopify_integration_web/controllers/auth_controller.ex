defmodule ShopifyIntegrationWeb.AuthController do
  use ShopifyIntegrationWeb, :controller

  require Logger

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

    Logger.info("OAuth initiation requested for shop: #{raw_shop}")

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
        Logger.warning("Missing shop domain in OAuth request")
        conn
        |> put_flash(:error, "Missing shop domain. Please enter e.g. mystore.myshopify.com")
        |> redirect(to: ~p"/")

      _ ->
        case Client.validate_shop_domain(shop_domain) do
          {:ok, valid_domain} ->
            Logger.info("Starting OAuth flow for shop: #{valid_domain}")

            # Generate a random state parameter for CSRF protection
            state = :crypto.strong_rand_bytes(16) |> Base.encode16()

            # Store state and shop in session for validation later
            conn =
              conn
              |> put_session(:shopify_oauth_state, state)
              |> put_session(:shopify_shop_domain, valid_domain)

            # Build the OAuth authorization URL using the client module
            oauth_url = Client.build_oauth_url(valid_domain, state)

            Logger.info("Redirecting to Shopify OAuth for shop: #{valid_domain}")
            # Redirect to Shopify's OAuth page
            redirect(conn, external: oauth_url)

          {:error, message} ->
            Logger.error("Shop domain validation failed for: #{shop_domain}. Error: #{message}")
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
    Logger.info("OAuth callback received for shop: #{shop_domain}")

    session_state = get_session(conn, :shopify_oauth_state)
    conn = delete_session(conn, :shopify_oauth_state)

    if is_nil(session_state) or session_state != state do
      Logger.warning("Invalid OAuth state for shop: #{shop_domain}. Expected: #{session_state}, Got: #{state}")
      conn
      |> put_flash(:error, "Invalid OAuth state. Please try again.")
      |> redirect(to: ~p"/")
    else
      # Verifies HMAC signature from Shopify
      with :ok <- verify_shopify_hmac(params),
           {:ok, _} <- Client.validate_shop_domain(shop_domain) do

        Logger.info("HMAC verification successful for shop: #{shop_domain}")

        case Client.exchange_code_for_token(shop_domain, code) do
          {:ok, %{"access_token" => access_token} = token_response} ->
            Logger.info("Successfully obtained access token for shop: #{shop_domain}")

            # Persist or update the shop with the access token
            case upsert_shop(shop_domain, access_token, Map.get(token_response, "scope")) do
              {:ok, shop} ->
                Logger.info("Shop record updated for: #{shop_domain}")
              {:error, reason} ->
                Logger.error("Failed to update shop record for: #{shop_domain}. Reason: #{inspect(reason)}")
            end

            # Auto-fetch orders after successful authentication
            Logger.info("Starting automatic order fetch for shop: #{shop_domain}")
            case Orders.fetch_and_store_orders(shop_domain, access_token) do
              {:ok, %{total_fetched: total, successful: successful, failed: failed}} ->
                Logger.info("Order fetch completed for shop: #{shop_domain}. Total: #{total}, Successful: #{successful}, Failed: #{failed}")
                message = "Connected to #{shop_domain}. Fetched #{total} orders (#{successful} stored, #{failed} failed)."

                conn
                |> put_flash(:info, message)
                |> redirect(to: ~p"/dashboard/shop/#{shop_domain}")

              {:error, reason} ->
                Logger.error("Order fetch failed for shop: #{shop_domain}. Reason: #{reason}")
                conn
                |> put_flash(:error, "Connected to #{shop_domain}, but failed to fetch orders: #{reason}")
                |> redirect(to: ~p"/dashboard/shop/#{shop_domain}")
            end

          {:error, err} ->
            Logger.error("Failed to exchange code for token for shop: #{shop_domain}. Error: #{err}")
            conn
            |> put_flash(:error, "Failed to get access token: #{err}")
            |> redirect(to: ~p"/")
        end
      else
        {:error, msg} ->
          Logger.error("OAuth callback validation failed for shop: #{shop_domain}. Error: #{msg}")
          conn
          |> put_flash(:error, to_string(msg))
          |> redirect(to: ~p"/")
      end
    end
  end

  def shopify_callback(conn, _params) do
    Logger.warning("OAuth callback received with invalid parameters")
    conn
    |> put_flash(:error, "OAuth authentication failed. Please try again.")
    |> redirect(to: ~p"/")
  end

  # Private helpers

  defp upsert_shop(shop_domain, access_token, scope) do
    Logger.debug("Upserting shop record for: #{shop_domain}")

    changes = %{shop_domain: shop_domain, access_token: access_token, scope: scope}

    case Repo.get_by(Shop, shop_domain: shop_domain) do
      nil ->
        Logger.debug("Creating new shop record for: #{shop_domain}")
        %Shop{}
        |> Shop.changeset(changes)
        |> Repo.insert()

      shop ->
        Logger.debug("Updating existing shop record for: #{shop_domain}")
        shop
        |> Shop.changeset(changes)
        |> Repo.update()
    end
  end

  defp verify_shopify_hmac(params) do
    provided_hmac = Map.get(params, "hmac")

    if is_nil(provided_hmac) do
      Logger.error("Missing HMAC in OAuth callback")
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
        Logger.debug("HMAC verification successful")
        :ok
      else
        Logger.error("HMAC verification failed. Expected: #{digest}, Got: #{provided_hmac}")
        {:error, "Invalid HMAC in callback."}
      end
    end
  end
end
