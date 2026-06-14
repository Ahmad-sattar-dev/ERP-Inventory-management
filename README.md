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

## Deploying to AWS (single EC2 + Docker Compose)

This deploys the whole stack (web + sidekiq + postgres + redis + Caddy for HTTPS)
to one EC2 instance using `docker-compose.prod.yml`. Suitable for a demo or an
internal tool (medium scale). Postgres/Redis data live on a **separate EBS volume**
so storage is easy to size and grow.

### 1. Launch the EC2 instance

- **AMI:** Ubuntu Server 24.04 LTS — pick the **Arm (64-bit Arm)** variant to use
  the cheaper Graviton instances below (the image builds natively on Arm).
- **Instance type:** `t4g.medium` (2 vCPU / 4 GB, **Arm/Graviton**) — ~20% cheaper
  than the equivalent `t3.medium` and a great fit for medium usage. Bump to
  `t4g.large` (8 GB) only when traffic grows. (x86 `t3.*` also works — the lockfile
  supports both architectures.)
- **Storage:**
  - Root volume: **30 GB gp3** (OS, Docker images, logs)
  - Add a second **gp3 data volume: 100 GB** (Postgres + Redis + backups). gp3 can
    be grown online later with no downtime.
- **Key pair:** create/download one for SSH.
- **Security group (inbound):**
  | Port | Source | Why |
  |------|--------|-----|
  | 22   | *your IP only* | SSH |
  | 80   | 0.0.0.0/0 | HTTP → redirects to HTTPS |
  | 443  | 0.0.0.0/0 | HTTPS |
  > Do **not** open 5432 or 6379 — Postgres/Redis stay on the internal Docker network.
- Allocate an **Elastic IP** and associate it with the instance (stable IP for DNS).

### 2. (Optional) Point a domain at it

**Testing now, no domain?** Skip this — set `DOMAIN=:80` in `.env.production` and
you'll access the app over plain HTTP at `http://<elastic-ip>/`.

**Have a domain?** Create an `A` record (e.g. `erp.yourdomain.com`) → the Elastic
IP and set `DOMAIN=erp.yourdomain.com`. Caddy then issues a TLS cert automatically
(HTTPS). You can switch from `:80` to a real domain anytime — just edit
`.env.production` and re-run the compose `up` command.

### 3. Install Docker on the instance

```bash
ssh -i your-key.pem ubuntu@<elastic-ip>
sudo apt update && sudo apt upgrade -y
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
sudo systemctl enable docker
exit                      # log out/in so the docker group applies
```

### 4. Mount the data volume at /mnt/data

```bash
lsblk                                  # find the new disk, e.g. /dev/nvme1n1
sudo mkfs -t ext4 /dev/nvme1n1         # FORMAT — only if the volume is brand new!
sudo mkdir -p /mnt/data
sudo mount /dev/nvme1n1 /mnt/data

# Make the mount permanent across reboots:
echo "UUID=$(sudo blkid -s UUID -o value /dev/nvme1n1) /mnt/data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

sudo mkdir -p /mnt/data/postgres /mnt/data/redis /mnt/data/backups
```

### 5. Get the code and configure secrets

```bash
git clone https://github.com/Ahmad-sattar-dev/ERP-Inventory-management.git
cd ERP-Inventory-management
cp .env.production.example .env.production

# Generate strong secrets:
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)"
echo "AR_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 32)"
echo "AR_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 32)"
echo "AR_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 32)"
echo "DATABASE_PASSWORD=$(openssl rand -base64 24)"
echo "SEED_API_TOKEN=$(openssl rand -hex 24)"

nano .env.production    # paste the values above + set DOMAIN and CORS_ORIGINS
```

### 6. Build and start

```bash
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml logs -f web   # watch migrate + seed
```

The entrypoint waits for Postgres, runs `db:prepare` (migrate + seed), and (with a
real domain) Caddy fetches a TLS cert. Then verify — use `http://<elastic-ip>` if
testing without a domain, or `https://your-domain` once DNS is set:

```bash
curl http://<elastic-ip>/health                         # => OK
curl http://<elastic-ip>/api/v1/products \
  -H "Authorization: Bearer <your SEED_API_TOKEN>"
```

### 7. Reliability (do this on a 4 GB instance)

On `t4g.medium` (4 GB RAM) the stack runs comfortably for medium/internal use, but
add a **swap file** so a memory spike can't trigger the OOM killer and take down
Postgres or the app:

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab   # persist across reboots
free -h                                                       # verify swap is active
```

Already handled for you in `docker-compose.prod.yml`:

- **`restart: always`** — Docker restarts any container that crashes.
- **`systemctl enable docker`** (step 3) — the whole stack returns after a reboot.
- **Log rotation** — container logs are capped so they can't fill the disk.

> This is a **single instance**, so it is not highly available — if the EC2 host
> itself fails, there's downtime until it recovers. That's fine for testing and
> most internal tools; move to ECS Fargate + RDS (multi-AZ) if you later need
> zero-downtime resilience.

### 8. Backups

```bash
# Nightly DB dump at 3am (optionally to S3 — set BACKUP_S3_BUCKET in env):
crontab -e
0 3 * * * /home/ubuntu/ERP-Inventory-management/scripts/backup_db.sh >> /var/log/erp-backup.log 2>&1
```

Also enable **EBS snapshots** of the data volume via AWS Backup / Data Lifecycle
Manager for point-in-time recovery.

### 9. Storage management

- Logs are capped (10 MB × 3 per container) so they can't fill the disk.
- Check usage: `df -h /mnt/data`
- **Grow storage with no downtime:** in the AWS console, modify the EBS volume to a
  larger size, then on the box:
  ```bash
  sudo resize2fs /dev/nvme1n1
  ```

### 10. Deploy updates later

```bash
cd ERP-Inventory-management
git pull
docker compose -f docker-compose.prod.yml up -d --build
```

`restart: always` brings every service back automatically after a reboot.

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
