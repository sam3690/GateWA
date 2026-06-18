#!/bin/bash
# =============================================================================
# GateWA - VPS Automated Setup Script
# =============================================================================
# This script will:
#   1. Update system packages
#   2. Install Docker & Docker Compose
#   3. Configure .env with secure keys
#   4. Build and start GateWA
#   5. Show you the URLs to access everything
#
# Usage:
#   chmod +x deploy/setup-vps.sh
#   sudo ./deploy/setup-vps.sh
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[GateWA]${NC} $1"; }
ok()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn(){ echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ─── Detect VPS IP ───────────────────────────────────────────────
detect_ip() {
    # Try multiple providers
    VPS_IP=$(curl -4 -s https://ifconfig.io 2>/dev/null || \
             curl -4 -s https://api.ipify.org 2>/dev/null || \
             curl -4 -s https://icanhazip.com 2>/dev/null || \
             hostname -I | awk '{print $1}')
    
    if [ -z "$VPS_IP" ]; then
        warn "Could not detect VPS IP automatically"
        read -p "Enter your VPS IP address: " VPS_IP
    fi
    ok "Detected VPS IP: $VPS_IP"
}

# ─── Ensure we're in the right directory ─────────────────────────
ensure_project_root() {
    if [ ! -f "docker-compose.yml" ] && [ ! -f "package.json" ]; then
        # Check if we're in deploy/ or the project root
        if [ -f "../docker-compose.yml" ]; then
            cd ..
        elif [ -f "../../docker-compose.yml" ]; then
            cd ../..
        else
            err "Cannot find GateWA project root. Run this script from the project directory."
        fi
    fi
    PROJECT_DIR=$(pwd)
    ok "Project directory: $PROJECT_DIR"
}

# ─── System Update ───────────────────────────────────────────────
system_update() {
    log "Updating system packages..."
    apt update && apt upgrade -y
    ok "System packages updated"
}

# ─── Install Docker ──────────────────────────────────────────────
install_docker() {
    if command -v docker &> /dev/null; then
        ok "Docker already installed: $(docker --version)"
    else
        log "Installing Docker..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sh /tmp/get-docker.sh
        ok "Docker installed: $(docker --version)"
    fi

    if docker compose version &> /dev/null; then
        ok "Docker Compose already installed: $(docker compose version)"
    else
        log "Installing Docker Compose plugin..."
        apt install -y docker-compose-plugin
        ok "Docker Compose installed: $(docker compose version)"
    fi
}

# ─── Configure .env ──────────────────────────────────────────────
configure_env() {
    if [ -f ".env" ]; then
        warn ".env already exists — backing up to .env.backup.$(date +%s)"
        cp .env ".env.backup.$(date +%s)"
    fi

    log "Configuring environment..."
    
    # Generate secure API key
    API_KEY=$(openssl rand -base64 32)
    
    # Copy the VPS template
    cp deploy/.env.vps .env
    
    # Replace the placeholder key
    sed -i "s|API_MASTER_KEY=CHANGE_ME_GENERATE_A_RANDOM_KEY|API_MASTER_KEY=$API_KEY|" .env
    
    ok "Environment configured"
    ok "Your API Master Key: ${YELLOW}$API_KEY${NC}"
    warn "SAVE THIS KEY — you won't see it again!"
    
    # Write key to a temporary file for display at the end
    echo "$API_KEY" > /tmp/gatewa_api_key.txt
}

# ─── Build & Start ────────────────────────────────────────────────
build_and_start() {
    log "Building Docker images (this takes 5-10 min the first time)..."
    docker compose -f deploy/docker-compose.vps.yml --env-file .env build
    
    log "Starting GateWA..."
    docker compose -f deploy/docker-compose.vps.yml --env-file .env up -d
    
    ok "GateWA started!"
}

# ─── Wait for Health ─────────────────────────────────────────────
wait_for_health() {
    log "Waiting for GateWA to be healthy..."
    local retries=0
    local max_retries=30
    
    while [ $retries -lt $max_retries ]; do
        if curl -sf http://localhost:2785/api/health > /dev/null 2>&1; then
            ok "GateWA API is healthy!"
            return 0
        fi
        sleep 5
        retries=$((retries + 1))
        echo -n "."
    done
    
    warn "Timed out waiting for health. Check logs: docker compose -f deploy/docker-compose.vps.yml logs"
}

# ─── Configure Firewall ──────────────────────────────────────────
configure_firewall() {
    log "Configuring UFW firewall..."
    
    # Check if UFW is available
    if ! command -v ufw &> /dev/null; then
        apt install -y ufw
    fi
    
    # Basic rules
    ufw --force disable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 2785/tcp comment 'GateWA API'
    ufw allow 2886/tcp comment 'GateWA Dashboard'
    
    # Enable
    ufw --force enable
    ok "Firewall configured"
    ok "Allowed ports: 22 (SSH), 2785 (API), 2886 (Dashboard)"
    warn "For production, restrict port 2785 and 2886 to specific IPs later:"
    warn "  ufw allow from YOUR_IP to any port 2785"
}

# ─── Print Summary ───────────────────────────────────────────────
print_summary() {
    API_KEY=$(cat /tmp/gatewa_api_key.txt 2>/dev/null || echo "See .env file")
    
    echo ""
    echo "══════════════════════════════════════════════════════════════"
    echo "              🎉 GateWA DEPLOYMENT COMPLETE! 🎉"
    echo "══════════════════════════════════════════════════════════════"
    echo ""
    echo "  📡 API Endpoint:"
    echo "     http://$VPS_IP:2785/api"
    echo ""
    echo "  📖 Swagger Docs:"
    echo "     http://$VPS_IP:2785/api/docs"
    echo ""
    echo "  🖥️  Dashboard:"
    echo "     http://$VPS_IP:2886"
    echo ""
    echo "  🔑 API Master Key:"
    echo "     $API_KEY"
    echo ""
    echo "  📋 Quick Test Commands:"
    echo ""
    echo "  # 1. Check API health:"
    echo "  curl http://$VPS_IP:2785/api/health"
    echo ""
    echo "  # 2. Create a WhatsApp session:"
    echo '  curl -X POST http://'$VPS_IP':2785/api/sessions \'
    echo '    -H "Content-Type: application/json" \'
    echo '    -H "X-API-Key: '$API_KEY'" \'
    echo '    -d "{\"name\": \"my-phone\"}"'
    echo ""
    echo "  # 3. Start session & get QR:"
    echo '  curl http://'$VPS_IP':2785/api/sessions/{sessionId}/qr \'
    echo '    -H "X-API-Key: '$API_KEY'"'
    echo ""
    echo "  📋 Management Commands:"
    echo "  docker compose -f deploy/docker-compose.vps.yml logs -f    # View logs"
    echo "  docker compose -f deploy/docker-compose.vps.yml restart    # Restart"
    echo "  docker compose -f deploy/docker-compose.vps.yml down       # Stop"
    echo ""
    echo "  ⚠️  SECURITY NOTES:"
    echo "  • Save your API key somewhere safe!"
    echo "  • Restrict firewall ports to trusted IPs when possible"
    echo "  • Add a domain + HTTPS for production use"
    echo ""
    echo "══════════════════════════════════════════════════════════════"
}

# ─── Main ─────────────────────────────────────────────────────────
main() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "   GateWA VPS Setup — $(date)"
    echo "═══════════════════════════════════════════════════"
    echo ""
    
    # Check root
    if [ "$EUID" -ne 0 ]; then
        err "Please run as root (use sudo)"
    fi
    
    ensure_project_root
    detect_ip
    system_update
    install_docker
    configure_env
    build_and_start
    wait_for_health
    configure_firewall
    print_summary
    
    # Clean up
    rm -f /tmp/gatewa_api_key.txt
}

main
