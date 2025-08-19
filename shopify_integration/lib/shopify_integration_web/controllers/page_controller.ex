defmodule ShopifyIntegrationWeb.PageController do
  use ShopifyIntegrationWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
