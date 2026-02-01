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

## Running Locally

```bash
# Setup
bundle install
rails db:create db:migrate db:seed

# Start server
rails server

# Start background jobs
bundle exec sidekiq

# Run tests
bundle exec rspec
```

## Sample API Usage

```bash
# Create order
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": 1,
    "line_items": [
      {"product_variant_id": 1, "quantity": 2, "price": 49.99}
    ]
  }'

# Update inventory
curl -X PATCH http://localhost:3000/api/v1/inventory/1 \
  -H "Content-Type: application/json" \
  -d '{"quantity": 100, "location_id": 1}'
```

## Author

Ahmad Sattar

---

*This is a demonstration project showcasing Ruby on Rails ERP development capabilities.*
