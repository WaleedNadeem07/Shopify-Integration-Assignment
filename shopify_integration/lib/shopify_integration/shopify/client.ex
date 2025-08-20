defmodule ShopifyIntegration.Shopify.Client do
  @moduledoc """
  Client module for interacting with Shopify's API.
  Handles OAuth flow, token exchange, and API requests.
  """

  require Logger

  @doc """
  Builds the OAuth authorization URL for a given shop domain.
  """
  def build_oauth_url(shop_domain, state) do
    api_key = get_api_key()
    redirect_uri = get_redirect_uri()
    scopes = get_required_scopes()

    Logger.info("Building OAuth URL for shop: #{shop_domain}")

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

    Logger.info("Exchanging code for token for shop: #{shop_domain}")

    body = %{
      "client_id" => api_key,
      "client_secret" => api_secret,
      "code" => code,
      "redirect_uri" => redirect_uri
    }

    case HTTPoison.post(url, Jason.encode!(body), [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, data} ->
            Logger.info("Successfully exchanged code for token for shop: #{shop_domain}")
            {:ok, data}
          {:error, _} ->
            Logger.error("Invalid JSON response from Shopify token exchange for shop: #{shop_domain}")
            {:error, "Invalid JSON response from Shopify"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("Shopify API error during token exchange for shop: #{shop_domain}. Status: #{status_code}, Body: #{response_body}")
        {:error, "Shopify API error: #{status_code} - #{response_body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed during token exchange for shop: #{shop_domain}. Reason: #{reason}")
        {:error, "HTTP request failed: #{reason}"}
    end
  end

  @doc """
  Validates a shop domain format.
  """
  def validate_shop_domain(shop_domain) do
    cond do
      String.ends_with?(shop_domain, ".myshopify.com") ->
        Logger.debug("Valid shop domain: #{shop_domain}")
        {:ok, shop_domain}

      String.ends_with?(shop_domain, ".myshopify.io") ->
        Logger.debug("Valid shop domain: #{shop_domain}")
        {:ok, shop_domain}

      true ->
        Logger.warning("Invalid shop domain format: #{shop_domain}")
        {:error, "Invalid shop domain format. Must end with .myshopify.com or .myshopify.io"}
    end
  end

  @doc """
  Makes an authenticated request to Shopify's API.
  """
  def api_request(shop_domain, access_token, endpoint, method \\ :get, body \\ nil) do
    url = "https://#{shop_domain}/admin/api/2024-07/#{endpoint}"

    Logger.info("Making #{String.upcase(to_string(method))} request to Shopify API for shop: #{shop_domain}, endpoint: #{endpoint}")

    headers = [
      {"X-Shopify-Access-Token", access_token},
      {"Content-Type", "application/json"}
    ]

    case method do
      :get ->
        case HTTPoison.get(url, headers) do
          {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
            case Jason.decode(response_body) do
              {:ok, data} ->
                Logger.info("Successfully fetched data from Shopify API for shop: #{shop_domain}, endpoint: #{endpoint}")
                {:ok, data}
              {:error, _} ->
                Logger.error("Invalid JSON response from Shopify API for shop: #{shop_domain}, endpoint: #{endpoint}")
                {:error, "Invalid JSON response from Shopify"}
            end

          {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
            Logger.error("Shopify API error for shop: #{shop_domain}, endpoint: #{endpoint}. Status: #{status_code}, Body: #{response_body}")
            {:error, "Shopify API error: #{status_code} - #{response_body}"}

          {:error, %HTTPoison.Error{reason: reason}} ->
            Logger.error("HTTP request failed for shop: #{shop_domain}, endpoint: #{endpoint}. Reason: #{reason}")
            {:error, "HTTP request failed: #{reason}"}
        end

      :post ->
        case HTTPoison.post(url, Jason.encode!(body), headers) do
          {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
            case Jason.decode(response_body) do
              {:ok, data} ->
                Logger.info("Successfully posted data to Shopify API for shop: #{shop_domain}, endpoint: #{endpoint}")
                {:ok, data}
              {:error, _} ->
                Logger.error("Invalid JSON response from Shopify API for shop: #{shop_domain}, endpoint: #{endpoint}")
                {:error, "Invalid JSON response from Shopify"}
            end

          {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
            Logger.error("Shopify API error for shop: #{shop_domain}, endpoint: #{endpoint}. Status: #{status_code}, Body: #{response_body}")
            {:error, "Shopify API error: #{status_code} - #{response_body}"}

          {:error, %HTTPoison.Error{reason: reason}} ->
            Logger.error("HTTP request failed for shop: #{shop_domain}, endpoint: #{endpoint}. Reason: #{reason}")
            {:error, "HTTP request failed: #{reason}"}
        end

      _ ->
        Logger.error("Unsupported HTTP method: #{method} for shop: #{shop_domain}")
        {:error, "Unsupported HTTP method: #{method}"}
    end
  end

  # Private helper functions

  defp get_api_key do
    presence(Application.get_env(:shopify_integration, __MODULE__)[:api_key]) ||
      presence(System.get_env("SHOPIFY_API_KEY"))
  end

  defp get_api_secret do
    presence(Application.get_env(:shopify_integration, __MODULE__)[:api_secret]) ||
      presence(System.get_env("SHOPIFY_API_SECRET"))
  end

  defp get_redirect_uri do
    presence(Application.get_env(:shopify_integration, __MODULE__)[:redirect_uri]) ||
      presence(System.get_env("SHOPIFY_REDIRECT_URI")) ||
      "http://localhost:4000/auth/shopify/callback"
  end

  defp get_required_scopes do
    presence(Application.get_env(:shopify_integration, __MODULE__)[:required_scopes]) ||
      presence(System.get_env("SHOPIFY_SCOPES")) ||
      "read_orders,read_all_orders,read_customers"
  end

  defp presence(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      other -> other
    end
  end

  defp presence(_), do: nil
end
