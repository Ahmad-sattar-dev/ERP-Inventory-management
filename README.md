# Apparel Inventory Management System

A Ruby on Rails ERP demo showcasing inventory management, order processing, and third-party integrations for apparel/fashion brands.

## Features

- **Inventory Management**: Track stock levels, variants (size/color), and warehouse locations
- **Order Management**: Process B2B and B2C orders with multi-status workflow
- **eCommerce Integration**: Sync with Shopify, WooCommerce
- **Accounting Integration**: Export to QuickBooks, Xero
- **Shipping Integration**: Generate labels via ShipStation, EasyPost
- **Background Processing**: Async jobs for inventory sync and order processing

## Tech Stack

- Ruby 3.2 / Rails 7.1
- PostgreSQL
- Redis + Sidekiq (background jobs)
- RSpec (testing)
- REST APIs

## Architecture

```
app/
├── models/
│   ├── product.rb          # Product catalog with variants
│   ├── inventory_item.rb   # Stock tracking per location
│   ├── order.rb            # Order management
│   ├── customer.rb         # B2B/B2C customers
│   └── integration.rb      # Third-party connection configs
├── controllers/api/v1/
│   ├── products_controller.rb
│   ├── orders_controller.rb
│   └── inventory_controller.rb
├── services/integrations/
│   ├── shopify_service.rb      # Shopify sync
│   ├── quickbooks_service.rb   # Accounting export
│   └── shipstation_service.rb  # Shipping labels
└── jobs/
    ├── inventory_sync_job.rb
    └── order_export_job.rb
```

## Key Implementations

### 1. Multi-Variant Inventory Tracking
- Products with size/color variants
- Stock levels per warehouse location
- Low stock alerts and reorder points

### 2. Order Workflow
```
draft → confirmed → processing → shipped → delivered
                 ↘ cancelled
```

### 3. Integration Pattern
- Webhook receivers for real-time sync
- Configurable retry logic with exponential backoff
- Comprehensive error logging

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/products` | List products with variants |
| POST | `/api/v1/orders` | Create new order |
| PATCH | `/api/v1/orders/:id/status` | Update order status |
| GET | `/api/v1/inventory` | Stock levels report |
| POST | `/api/v1/webhooks/shopify` | Shopify webhook receiver |

## Running with Docker (recommended)

The repository ships with a `Dockerfile` and a `docker-compose.yml` that bring up
the full stack — Rails web server, Sidekiq worker, PostgreSQL, and Redis — so a new
developer can get running without installing Ruby, Postgres, or Redis locally.

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) 20.10+
- [Docker Compose](https://docs.docker.com/compose/) v2 (bundled with Docker Desktop)

### First-time setup

```bash
# 1. Clone the repo and enter it
git clone <repo-url>
cd ERP-Inventory-management

# 2. Create your local environment file from the template
cp .env.example .env
#    The demo defaults work out of the box. For a real deployment, set
#    SECRET_KEY_BASE, the AR_ENCRYPTION_* keys, SEED_API_TOKEN, and any
#    third-party API keys.

# 3. Build the images and start everything
docker compose up --build
```

On first boot the entrypoint waits for PostgreSQL, then runs `rails db:prepare`
(create + migrate + **seed**) automatically. Seeding creates demo products,
inventory, a customer, and an **API key** (see Authentication below).

The API is then available at **http://localhost:3000** — try the health check:

```bash
curl http://localhost:3000/health   # => OK
```

> **Port already in use?** If you already run PostgreSQL or Redis locally, the
> default host ports (5432 / 6379) will clash. Set alternatives in `.env`:
> ```
> DATABASE_HOST_PORT=55432
> REDIS_HOST_PORT=56379
> ```
> These only change the *host-side* ports; the app talks to `db`/`redis` over
> the internal Docker network regardless.

### Authentication

All `/api/v1/*` endpoints require a Bearer token. The seed data creates one from
`SEED_API_TOKEN` (default `dev-token-please-change-me`). Send it on every request:

```bash
curl http://localhost:3000/api/v1/products \
  -H "Authorization: Bearer dev-token-please-change-me"
```

The `/health` endpoint is public (no token needed).

### Everyday commands

```bash
docker compose up               # start the stack (web + sidekiq + db + redis)
docker compose up -d            # start in the background
docker compose down             # stop and remove containers (data is kept in volumes)
docker compose down -v          # also delete the Postgres/Redis data volumes

# Run a one-off command inside the web container
docker compose run --rm web bundle exec rspec           # run the test suite
docker compose run --rm web bundle exec rails console   # open a Rails console
docker compose run --rm web bundle exec rails db:migrate

# Tail logs
docker compose logs -f web
docker compose logs -f sidekiq
```

> **Note:** `config/database.yml` reads its connection details from environment
> variables, so the same config works locally and in Docker (where `DATABASE_HOST`
> resolves to the `db` service automatically).

## Running Locally (without Docker)

```bash
# Prerequisites: Ruby 3.2, PostgreSQL, and Redis running locally
cp .env.example .env            # then fill in values

# Setup
bundle install
bin/rails db:create db:migrate db:seed

# Start server
bin/rails server

# Start background jobs
bundle exec sidekiq

# Run tests
bundle exec rspec
```

> **What works vs. what's stubbed.** The core ERP functionality runs fully:
> products & variants, multi-location inventory (adjustments, reservations,
> movements, low-stock), the order lifecycle (the `draft → … → delivered` state
> machine via AASM), customers, pagination, and Bearer-token auth — all backed by
> real PostgreSQL tables. The **third-party integrations** (Shopify, QuickBooks,
> ShipStation) and the webhook/sync background jobs are wired up but make live API
> calls, so they only do real work once you create an `Integration` record with
> valid credentials. The notification mailers are stubs that log/produce a plain
> message rather than render templated emails.

## Sample API Usage

All requests need the `Authorization: Bearer <token>` header (see Authentication
above). The examples below use the default seeded token.

```bash
TOKEN=dev-token-please-change-me

# List products
curl http://localhost:3000/api/v1/products \
  -H "Authorization: Bearer $TOKEN"

# Create an order (note the nested `order` / `line_items_attributes` shape)
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "order": {
      "customer_id": 1,
      "line_items_attributes": [
        {"product_variant_id": 1, "quantity": 2, "unit_price": 24.99}
      ]
    }
  }'

# Adjust inventory for an item (+/- delta)
curl -X POST http://localhost:3000/api/v1/inventory/1/adjust \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"quantity": 50, "reason": "restock"}'

# Inventory summary report
curl http://localhost:3000/api/v1/inventory/summary \
  -H "Authorization: Bearer $TOKEN"
```

## Author

Ahmad Sattar

---

*This is a demonstration project showcasing Ruby on Rails ERP development capabilities.*
