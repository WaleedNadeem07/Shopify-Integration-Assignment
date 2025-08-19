defmodule ShopifyIntegrationWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use ShopifyIntegrationWeb, :html

  embed_templates "page_html/*"

  attr :action, :string, required: true
  attr :method, :string, default: "get"
  attr :class, :string, default: ""
  slot :inner_block
  def simple_form(assigns) do
    ~H"""
    <form action={@action} method={@method} class={@class}><%= render_slot(@inner_block) %></form>
    """
  end
end
