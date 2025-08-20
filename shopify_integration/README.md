# Shopify Integration Assignment

A Phoenix application that integrates with Shopify to authenticate users and fetch their orders.

## Overview

This project:
- Sets up a Phoenix web application
- Implements Shopify OAuth authentication
- Fetches and stores Shopify orders
- Handles errors gracefully with proper logging

## Tech Stack

- **Backend**: Elixir/Phoenix
- **Database**: PostgreSQL
- **Authentication**: Shopify OAuth
- **API Integration**: Shopify REST API

## Prerequisites

- Elixir and Erlang installed (see [Elixir Install](https://elixir-lang.org/install.html))
- PostgreSQL running locally
- Phoenix archive installed:
```bash
mix archive.install hex phx_new
```

## Setup

1) Install dependencies
```bash
cd shopify_integration
mix deps.get
```

2) Configure environment variables
- I have already put a .env file, you just need to update it with your credentials
    SHOPIFY_API_KEY=your_api_key
    SHOPIFY_API_SECRET=your_api_secret
    SHOPIFY_REDIRECT_URI=http://localhost:4000/auth/shopify/callback
    # Optional default for convenience when no shop param provided
    SHOPIFY_STORE_DOMAIN=your-dev-store.myshopify.com

3) Configure Shopify app callback URL
- In your Shopify app settings (Dev store: Admin → Apps → Develop apps → Your App → App setup; Partner app: Partner Dashboard → Apps → Your App → App setup), add this to Allowed redirection URL(s):
  - `http://localhost:4000/auth/shopify/callback`

4) Database setup
```bash
mix ecto.create
mix ecto.migrate
```

5) Run the app
```bash
mix phx.server
```
Open `http://localhost:4000` and connect your store.

## How it works

- Visit `/` and enter your shop (short form like `mystore` or full `mystore.myshopify.com`).
- The app constructs the Shopify OAuth URL and redirects you to Shopify.
- After you approve, Shopify redirects to `/auth/shopify/callback`.
- The app verifies the HMAC, exchanges the code for an access token, stores the shop, and automatically fetches up to 250 orders (any status) and stores them in Postgres.
- You are redirected to `/dashboard/shop/:shop_domain` where you can see orders and basic stats.
