# GateWA VPS Deployment Guide

> Complete guide: DigitalOcean Droplet → GateWA → n8n → Hermes Agent

---

## 📦 Part 1 — Provision Your DigitalOcean Droplet

### Step 1: Create Droplet

1. Go to [cloud.digitalocean.com](https://cloud.digitalocean.com) and log in
2. Click **Create** → **Droplets**
3. Choose:
   - **Region**: Choose the closest to you (e.g., Singapore, Frankfurt, NYC)
   - **Image**: **Ubuntu 24.04 LTS x64**
   - **Size**: **Basic** → **4 GB / 2 vCPU / 80 GB SSD** ($24/mo)
   - **Authentication**: **SSH Key** (add your public key) or **Password**
     > **Recommendation**: SSH key is more secure. If you don't have one:
     > ```bash
     > # On your local machine, generate an SSH key:
     > ssh-keygen -t ed25519 -C "your-email@example.com"
     > # Show the public key to copy into DO:
     > cat ~/.ssh/id_ed25519.pub
     > ```
   - **Hostname**: `gatewa-vps` (or whatever you like)
4. Click **Create Droplet**
5. Wait ~30 seconds for it to provision
6. Note the **IP address** shown in your DO dashboard

### Step 2: SSH Into Your VPS

```bash
ssh root@<YOUR_VPS_IP>
```

Example:
```bash
ssh root@159.89.100.100
```

If you get a "Host key not found" warning, type `yes` to continue.

---

## ⚙️ Part 2 — One-Click GateWA Setup

### Option A: Run the Automated Script (Recommended)

```bash
# Clone the repository
apt update && apt install -y git
git clone https://github.com/sam3690/GateWA.git
cd GateWA

# Run the setup script
chmod +x deploy/setup-vps.sh
sudo ./deploy/setup-vps.sh
```

The script will:
1. Update system packages
2. Install Docker & Docker Compose
3. Generate a secure API key
4. Build Docker images
5. Start GateWA (API + Dashboard)
6. Configure firewall (ports 22, 2785, 2886)
7. Print your access URLs

**⏱️ First build takes 5-10 minutes** (Chromium + Node.js dependencies)

### Option B: Manual Setup (if you prefer step-by-step)

```bash
# 1. Update system
apt update && apt upgrade -y

# 2. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
apt install -y docker-compose-plugin

# 3. Clone & configure
git clone https://github.com/sam3690/GateWA.git
cd GateWA
cp deploy/.env.vps .env

# 4. Generate API key
API_KEY=$(openssl rand -base64 32)
sed -i "s|API_MASTER_KEY=CHANGE_ME_GENERATE_A_RANDOM_KEY|API_MASTER_KEY=$API_KEY|" .env
echo "Your API Key: $API_KEY"
echo "$API_KEY" > ~/gatewa_api_key.txt  # Save it!

# 5. Build & start
docker compose -f deploy/docker-compose.vps.yml --env-file .env build
docker compose -f deploy/docker-compose.vps.yml --env-file .env up -d

# 6. Verify health
sleep 10
curl http://localhost:2785/api/health

# 7. Configure firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 2785/tcp comment 'GateWA API'
ufw allow 2886/tcp comment 'GateWA Dashboard'
ufw --force enable
```

---

## ✅ Part 3 — Verify Everything Works

### Check Health

```bash
# From your VPS:
curl http://localhost:2785/api/health
# Expected: {"status":"ok","timestamp":"..."}
```

### Access From Your Browser

Open these URLs in your browser (replace with your VPS IP):

| Service | URL |
|---|---|
| Dashboard | `http://<YOUR_VPS_IP>:2886` |
| Swagger API Docs | `http://<YOUR_VPS_IP>:2785/api/docs` |
| API Health | `http://<YOUR_VPS_IP>:2785/api/health` |

> ⚠️ **No HTTPS yet** — that's fine for initial testing. We'll add it later.

### Create a WhatsApp Session via API

```bash
API_KEY="<your-api-key-from-setup>"
VPS_IP="<your-vps-ip>"

# Create a session
curl -X POST http://$VPS_IP:2785/api/sessions \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{"name": "my-phone"}'

# List sessions (note the sessionId returned)
curl http://$VPS_IP:2785/api/sessions \
  -H "X-API-Key: $API_KEY"

# Start the session
curl -X POST http://$VPS_IP:2785/api/sessions/{sessionId}/start \
  -H "X-API-Key: $API_KEY"

# Get QR code (open this in browser to scan with WhatsApp)
curl http://$VPS_IP:2785/api/sessions/{sessionId}/qr \
  -H "X-API-Key: $API_KEY"
```

> **To scan the QR**: Open the QR URL in your browser, then open WhatsApp on your phone → Linked Devices → Link a Device → scan the QR code.

---

## 🛡️ Part 4 — Security Hardening

### Restrict API Access to Your IP Only

```bash
# Allow only YOUR IP to access the API and dashboard
ufw delete allow 2785/tcp
ufw delete allow 2886/tcp
ufw allow from YOUR_HOME_IP to any port 2785 proto tcp
ufw allow from YOUR_HOME_IP to any port 2886 proto tcp
```

### Set Up SSH Key Only (disable password login)

```bash
# Edit SSH config
nano /etc/ssh/sshd_config

# Set these:
#   PermitRootLogin prohibit-password
#   PasswordAuthentication no
#   PubkeyAuthentication yes

# Restart SSH
systemctl restart sshd
```

### Regular Backups

```bash
# Backup GateWA data
tar -czf ~/gatewa-backup-$(date +%Y%m%d).tar.gz /opt/GateWA/data
```

---

## 🔗 Part 5 — Deploy n8n

After GateWA is running, deploy n8n for workflow automation:

```bash
# Run n8n as a Docker container
docker run -d \
  --name n8n \
  --restart unless-stopped \
  -p 5678:5678 \
  -v n8n-data:/home/node/.n8n \
  -e N8N_SECURE_COOKIE=false \
  -e WEBHOOK_URL=http://<YOUR_VPS_IP>:5678/ \
  n8nio/n8n

# Allow port
ufw allow 5678/tcp comment 'n8n'
```

**Access**: `http://<YOUR_VPS_IP>:5678`

### Connect n8n to GateWA

GateWA has a dedicated n8n integration guide:
```
docs/22-n8n-integration.md
```

The basic flow in n8n:
1. **Incoming message trigger** → GateWA webhook → n8n workflow → process → respond
2. **Scheduled workflow** → n8n → GateWA API → send WhatsApp message
3. **AI agent** → n8n AI tools → GateWA → WhatsApp conversation

---

## 🤖 Part 6 — Deploy Hermes Agent

Hermes Agent is **197K stars on GitHub** from Nous Research. It's a self-improving AI agent that lives on your server.

```bash
# SSH into your VPS

# Install Hermes (one command, no sudo needed)
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

# Run setup wizard
hermes setup

# Set your model provider (OpenRouter, Nous Portal, OpenAI, etc.)
hermes model

# Start chatting in the terminal
hermes

# Optional: Install as a gateway service (for WhatsApp, Telegram, etc.)
hermes gateway setup
hermes gateway install
```

### How Hermes + GateWA Work Together

| Use Case | How |
|---|---|
| **Hermes sends WhatsApp via GateWA** | Hermes calls GateWA REST API to send messages programmatically |
| **Hermes receives WhatsApp via GateWA webhooks** | GateWA webhook → n8n → Hermes or directly to Hermes HTTP endpoint |
| **Hermes uses its own WhatsApp gateway** | Hermes has built-in WhatsApp support via its gateway system |
| **n8n orchestrates both** | n8n workflows can route between GateWA and Hermes |

**Recommended architecture**:
- GateWA → WhatsApp REST API layer (for programmatic access from n8n, apps)
- Hermes → AI agent with its own WhatsApp gateway (for agent-driven conversations)
- n8n → Glue logic, workflow automation connecting all services

---

## 🌐 Part 7 — Add HTTPS (Future)

Once you get a domain name, you have two options:

### Option A: Cloudflare Tunnel (Free, No Open Ports)

```bash
# Install cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
cloudflared tunnel login
cloudflared tunnel create gatewa
cloudflared tunnel route dns gatewa wa.yourdomain.com
cloudflared tunnel run gatewa
```

### Option B: Traefik + Let's Encrypt (GateWA already supports this)

Switch to the production `docker-compose.yml` with Traefik profile, set your domain in `.env`:
```
DOMAIN=wa.yourdomain.com
TRAEFIK_ACME_EMAIL=admin@yourdomain.com
PROXY_ENABLED=true
```

Then:
```bash
docker compose --profile full up -d
```

This auto-provisions HTTPS via Let's Encrypt.

---

## 📊 Resource Budget

| Service | RAM | Notes |
|---|---|---|
| OS + Docker overhead | ~500 MB | Ubuntu + container runtime |
| GateWA API | ~300 MB | NestJS + SQLite |
| Chromium (Puppeteer) | ~200 MB | Shared across sessions |
| **Per WhatsApp session** | ~300-400 MB | Each linked phone |
| n8n | ~200-400 MB | Workflow engine |
| Hermes Agent | ~200-500 MB | AI agent + memory |
| **Your AI apps** | ~200-500 MB each | Varies |

**With 4 GB RAM**: Start with **2-3 WhatsApp sessions** + n8n + Hermes. You have room to grow.

---

## 🛠️ Common Management Commands

```bash
# View GateWA logs
docker compose -f deploy/docker-compose.vps.yml logs -f

# View GateWA API logs only
docker compose -f deploy/docker-compose.vps.yml logs -f gatewa

# Restart GateWA
docker compose -f deploy/docker-compose.vps.yml restart

# Stop GateWA
docker compose -f deploy/docker-compose.vps.yml down

# Start GateWA
docker compose -f deploy/docker-compose.vps.yml up -d

# Rebuild after updates
docker compose -f deploy/docker-compose.vps.yml build
docker compose -f deploy/docker-compose.vps.yml up -d

# Check container status
docker compose -f deploy/docker-compose.vps.yml ps
```

---

## 📁 Files Reference

| File | Purpose |
|---|---|
| `deploy/.env.vps` | Environment template for VPS (no domain) |
| `deploy/docker-compose.vps.yml` | Docker Compose for VPS (direct IP access) |
| `deploy/setup-vps.sh` | One-click automated setup script |
| `deploy/DEPLOYMENT-GUIDE.md` | This guide |
| `docs/22-n8n-integration.md` | n8n + GateWA integration guide |
