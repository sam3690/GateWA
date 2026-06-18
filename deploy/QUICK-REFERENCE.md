# GateWA VPS — Quick Reference Card

## Your Services

```
API:       http://<VPS_IP>:2785/api
Swagger:   http://<VPS_IP>:2785/api/docs
Dashboard: http://<VPS_IP>:2886
n8n:       http://<VPS_IP>:5678
```

## Key Commands

```bash
# --- GateWA ---
cd /opt/GateWA
docker compose -f deploy/docker-compose.vps.yml logs -f
docker compose -f deploy/docker-compose.vps.yml restart
docker compose -f deploy/docker-compose.vps.yml down
docker compose -f deploy/docker-compose.vps.yml up -d

# --- Backup ---
tar -czf ~/gatewa-backup-$(date +%Y%m%d).tar.gz /opt/GateWA/data

# --- n8n ---
docker logs -f n8n
docker restart n8n
```

## API Quick Start

```bash
API_KEY="<your-key>"
VPS="<your-ip>"

# Health check
curl http://$VPS:2785/api/health

# Create session
curl -X POST http://$VPS:2785/api/sessions \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"my-phone"}'

# List sessions
curl http://$VPS:2785/api/sessions -H "X-API-Key: $API_KEY"

# Send text message
curl -X POST http://$VPS:2785/api/sessions/{id}/messages/send-text \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"chatId":"628xxx@c.us","text":"Hello from GateWA!"}'
```

## Security Notes

- Change `API_MASTER_KEY` in `.env` if it leaks
- Restrict ports to trusted IPs: `ufw allow from YOUR_IP to any port 2785`
- Add a domain + HTTPS before production WhatsApp use
- DigitalOcean allows live resizing up to 8 GB / 16 GB RAM without reprovisioning
