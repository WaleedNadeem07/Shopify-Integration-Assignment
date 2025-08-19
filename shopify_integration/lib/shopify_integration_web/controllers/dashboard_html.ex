defmodule ShopifyIntegrationWeb.DashboardHTML do
  use ShopifyIntegrationWeb, :html

  embed_templates "dashboard_html/*"

  def get_status_class(status) do
    base_classes = "inline-flex px-2 py-1 text-xs font-semibold rounded-full"

    status_classes = case status do
      "paid" -> "bg-green-100 text-green-800"
      "pending" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end

    "#{base_classes} #{status_classes}"
  end
end
