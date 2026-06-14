# AWS Deployment Guide — Apparel Inventory Management

Complete, start-to-finish guide to deploy this app on a single AWS EC2 instance
using Docker Compose. Follow it top to bottom.

**This guide targets the chosen setup:**

| Choice | Value |
|--------|-------|
| Region | **Asia Pacific (Mumbai) — `ap-south-1`** (closest to Pakistan) |
| Instance | **t4g.medium** (2 vCPU / 4 GB, Arm/Graviton — ~20% cheaper) |
| Storage | **30 GB root + 30 GB data** (gp3), grows online later |
| URL | **Plain HTTP on the Elastic IP** (no domain yet) |
| Cost | **~$22/month** with the weekday 9 AM–9 PM auto start/stop |

> When you later get a domain, it's a one-line change (Step 11) to switch to HTTPS.

---

## 0. What you're deploying

One EC2 instance runs the whole stack with Docker Compose:

```
Internet → Caddy (:80) → web (Rails/Puma)
                          sidekiq (background jobs)
                          postgres  ─┐ data on a dedicated
                          redis      ┘ EBS volume (/mnt/data)
```

---

## 1. Prerequisites

- An AWS account (with billing set up).
- On your computer: an SSH client (built into macOS/Linux/Windows terminal).
- **Set your region first:** in the AWS console top-right dropdown, choose
  **Asia Pacific (Mumbai) ap-south-1**. Do this before creating anything.

---

## 2. Create an SSH key pair

1. EC2 console → **Network & Security → Key Pairs → Create key pair**.
2. Name: `erp-key`, type **ED25519** (or RSA), format **.pem**.
3. Download `erp-key.pem` and keep it safe. On your machine:
   ```bash
   chmod 400 ~/Downloads/erp-key.pem
   ```

---

## 3. Launch the EC2 instance

EC2 console → **Instances → Launch instances**:

1. **Name:** `erp-server`
2. **AMI:** Ubuntu Server 24.04 LTS → switch the architecture to **64-bit (Arm)**.
   (Arm is required for the cheaper t4g instance.)
3. **Instance type:** `t4g.medium`
4. **Key pair:** select `erp-key`.
5. **Network settings → Edit → Security group** (create new, name `erp-sg`) with
   these inbound rules:

   | Type | Port | Source | Why |
   |------|------|--------|-----|
   | SSH | 22 | **My IP** | admin access |
   | HTTP | 80 | Anywhere (0.0.0.0/0) | the app URL |
   | HTTPS | 443 | Anywhere (0.0.0.0/0) | for later, when you add a domain |

   > Do **not** add 5432 or 6379 — the database and Redis stay private.

6. **Configure storage:**
   - Root volume: **30 GB**, type **gp3**.
   - Click **Add new volume**: **30 GB**, type **gp3** (this is the database/data
     volume).
7. **Launch instance.**

---

## 4. Allocate a static IP (Elastic IP)

So your URL never changes across stop/start:

1. EC2 → **Network & Security → Elastic IPs → Allocate Elastic IP address** → Allocate.
2. Select it → **Actions → Associate** → choose your `erp-server` instance → Associate.
3. Note this IP — it's your app URL. Call it `<ELASTIC_IP>` below.

---

## 5. Connect to the server

```bash
ssh -i ~/Downloads/erp-key.pem ubuntu@<ELASTIC_IP>
```

(Type `yes` at the fingerprint prompt the first time.)

---

## 6. Update the system and add swap

Swap protects the 4 GB box from running out of memory under load:

```bash
sudo apt update && sudo apt upgrade -y

sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h     # confirm 2.0Gi swap is active
```

---

## 7. Install Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
sudo systemctl enable docker     # auto-start Docker on every boot
exit                             # log out so the docker group takes effect
```

Reconnect:

```bash
ssh -i ~/Downloads/erp-key.pem ubuntu@<ELASTIC_IP>
docker --version                 # verify
```

---

## 8. Mount the data volume at /mnt/data

```bash
lsblk          # find the 30 GB data disk — usually /dev/nvme1n1 (NOT the root disk)
```

Once you've identified it (assume `/dev/nvme1n1`):

```bash
sudo mkfs -t ext4 /dev/nvme1n1            # FORMAT — only because it's brand new!
sudo mkdir -p /mnt/data
sudo mount /dev/nvme1n1 /mnt/data

# Persist across reboots (nofail = don't block boot if the disk is missing)
echo "UUID=$(sudo blkid -s UUID -o value /dev/nvme1n1) /mnt/data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

sudo mkdir -p /mnt/data/postgres /mnt/data/redis /mnt/data/backups
df -h /mnt/data    # confirm it's mounted
```

> ⚠️ Only run `mkfs` on a **new, empty** volume. Never on one with data — it erases it.

---

## 9. Get the code and configure secrets

```bash
git clone https://github.com/Ahmad-sattar-dev/ERP-Inventory-management.git
cd ERP-Inventory-management
cp .env.production.example .env.production

# Generate strong secrets and print them:
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)"
echo "AR_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 32)"
echo "AR_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 32)"
echo "AR_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 32)"
echo "DATABASE_PASSWORD=$(openssl rand -base64 24)"
echo "SEED_API_TOKEN=$(openssl rand -hex 24)"

nano .env.production
```

In the editor, paste the generated values into the matching keys and confirm:

- `DOMAIN=:80`  ← serves plain HTTP on the IP (no domain needed)
- `RAILS_ENV=production`
- `DATABASE_USER=apparel_inventory`
- `DATABASE_NAME=apparel_inventory_production`
- `CORS_ORIGINS=*`  (fine for testing)

Save (Ctrl-O, Enter) and exit (Ctrl-X). **Keep your `SEED_API_TOKEN`** — it's how
you authenticate to the API.

---

## 10. Build and start the app

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

First build takes a few minutes (it compiles gems). Watch it migrate and seed:

```bash
docker compose -f docker-compose.prod.yml logs -f web
```

When you see `Listening on http://0.0.0.0:3000`, it's up. Press Ctrl-C to stop
tailing (the app keeps running).

Verify from your own machine:

```bash
curl http://<ELASTIC_IP>/health        # => OK

curl http://<ELASTIC_IP>/api/v1/products \
  -H "Authorization: Bearer <your SEED_API_TOKEN>"
```

🎉 Your API is live at `http://<ELASTIC_IP>`.

---

## 11. (Later) Add a domain + HTTPS

When you have a domain:

1. Create a DNS **A record** `erp.yourdomain.com` → `<ELASTIC_IP>`.
2. On the server: `nano .env.production` → set `DOMAIN=erp.yourdomain.com`.
3. `docker compose -f docker-compose.prod.yml up -d`
4. Caddy fetches a free TLS cert automatically → `https://erp.yourdomain.com`.

---

## 12. Automatic backups

```bash
crontab -e
```

Add (nightly DB dump at 3 AM, kept 14 days under /mnt/data/backups):

```
0 3 * * * /home/ubuntu/ERP-Inventory-management/scripts/backup_db.sh >> /var/log/erp-backup.log 2>&1
```

Optional off-server copy to S3: create a bucket, give the instance an IAM role with
`s3:PutObject` on it, and add `BACKUP_S3_BUCKET=your-bucket` to `.env.production`.

Also recommended: AWS console → **EBS → Lifecycle Manager** → snapshot the data
volume daily for point-in-time recovery.

---

## 13. Auto start/stop to cut cost (weekday 9 AM–9 PM PKT → ~$22/mo)

Uses EventBridge Scheduler to start/stop the instance automatically. The app
returns on its own when the instance starts (`restart: always` + Docker enabled).

**A. Create a role the scheduler can use** (run locally with AWS CLI, or use the console):

```bash
cat > scheduler-trust.json <<'JSON'
{ "Version": "2012-10-17", "Statement": [{
  "Effect": "Allow",
  "Principal": { "Service": "scheduler.amazonaws.com" },
  "Action": "sts:AssumeRole" }] }
JSON

aws iam create-role --role-name ec2-scheduler-role \
  --assume-role-policy-document file://scheduler-trust.json

aws iam put-role-policy --role-name ec2-scheduler-role \
  --policy-name ec2-start-stop \
  --policy-document '{ "Version":"2012-10-17","Statement":[{
    "Effect":"Allow","Action":["ec2:StartInstances","ec2:StopInstances"],
    "Resource":"*" }] }'
```

**B. Create the two schedules** (replace `<ACCOUNT_ID>` and `<INSTANCE_ID>`):

```bash
ROLE_ARN="arn:aws:iam::<ACCOUNT_ID>:role/ec2-scheduler-role"

aws scheduler create-schedule --name erp-start \
  --schedule-expression "cron(0 9 ? * MON-FRI *)" \
  --schedule-expression-timezone "Asia/Karachi" \
  --flexible-time-window '{"Mode":"OFF"}' \
  --target '{"Arn":"arn:aws:scheduler:::aws-sdk:ec2:startInstances","RoleArn":"'"$ROLE_ARN"'","Input":"{\"InstanceIds\":[\"<INSTANCE_ID>\"]}"}'

aws scheduler create-schedule --name erp-stop \
  --schedule-expression "cron(0 21 ? * MON-FRI *)" \
  --schedule-expression-timezone "Asia/Karachi" \
  --flexible-time-window '{"Mode":"OFF"}' \
  --target '{"Arn":"arn:aws:scheduler:::aws-sdk:ec2:stopInstances","RoleArn":"'"$ROLE_ARN"'","Input":"{\"InstanceIds\":[\"<INSTANCE_ID>\"]}"}'
```

**Console alternative:** EventBridge → Scheduler → Create schedule → Recurring,
cron `0 9 ? * MON-FRI *`, timezone **Asia/Karachi** → Target **All APIs** → EC2 →
`StartInstances`, Input `{"InstanceIds":["<INSTANCE_ID>"]}`. Repeat with `0 21 ...`
and `StopInstances`.

> Storage and the Elastic IP are still billed while stopped, so the URL and data
> are preserved — only compute pauses. Allow ~1–2 minutes after start-up before
> the API responds.

---

## 14. Day-2 operations

**Deploy updates:**
```bash
cd ERP-Inventory-management && git pull
docker compose -f docker-compose.prod.yml up -d --build
```

**Common commands:**
```bash
docker compose -f docker-compose.prod.yml ps               # status
docker compose -f docker-compose.prod.yml logs -f web      # app logs
docker compose -f docker-compose.prod.yml logs -f sidekiq  # job logs
docker compose -f docker-compose.prod.yml restart web      # restart one service
docker compose -f docker-compose.prod.yml down             # stop the stack
```

**Rails console / one-off tasks:**
```bash
docker compose -f docker-compose.prod.yml exec web bin/rails console
docker compose -f docker-compose.prod.yml exec web bin/rails db:migrate
```

**Grow storage with no downtime** (when `df -h /mnt/data` gets ~70% full): increase
the EBS volume size in the AWS console, then on the box:
```bash
sudo resize2fs /dev/nvme1n1
```

---

## 15. Troubleshooting

| Symptom | Check |
|---------|-------|
| `curl` to the IP times out | Security group allows port 80 from your network? Instance running? |
| 401 on every API call | Missing/incorrect `Authorization: Bearer <SEED_API_TOKEN>` header |
| Web container restarting | `docker compose -f docker-compose.prod.yml logs web` — usually a bad value in `.env.production` |
| "out of memory" / killed | Confirm swap is on (`free -h`); consider `t4g.large` |
| Disk full | `df -h` and `docker system prune -f` to remove unused images |
| DB won't start after reboot | Is `/mnt/data` mounted? `df -h /mnt/data`; check `/etc/fstab` |

---

## 16. Cost summary (Mumbai, estimates)

| Item | Always-on | Weekday 9–9 (scheduled) |
|------|-----------|--------------------------|
| EC2 t4g.medium | ~$31.50 | ~$9.50 |
| EBS 60 GB gp3 | ~$5.50 | ~$5.50 |
| Elastic IP | ~$3.65 | ~$3.65 |
| Snapshots/transfer | ~$2–3 | ~$1–2 |
| **Total** | **~$42–45/mo** | **~$20–22/mo** |
