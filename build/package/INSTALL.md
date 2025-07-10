# Alertmanager Discord Webhook - Installation Guide

## Quick Installation

1. **Extract the package**:
```bash
tar -xzf alertmanager-discord-linux-amd64.tar.gz
cd alertmanager-discord
```

2. **Configure Discord webhook**:
```bash
# Edit environment file
nano alertmanager-discord.env

# Set your Discord webhook URL
DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
DISCORD_USERNAME="AlertBot"
```

3. **Install as systemd service**:
```bash
sudo ./install-service.sh install
```

4. **Check status**:
```bash
sudo systemctl status alertmanager-discord
```

## Files Included

- `alertmanager-discord` - Main binary
- `alertmanager-discord.service` - Systemd service file
- `alertmanager-discord.env` - Environment configuration
- `alertmanager.yaml` - Example Alertmanager configuration
- `install-service.sh` - Service installation script
- `README.md` - Complete documentation
- `SYSTEMD_GUIDE.md` - Systemd setup guide

## Configuration

### Discord Webhook
1. Go to your Discord server settings
2. Navigate to Integrations → Webhooks
3. Create a new webhook or use existing one
4. Copy the webhook URL
5. Update `alertmanager-discord.env` with the URL

### Alertmanager
Add webhook configuration to your `alertmanager.yml`:

```yaml
route:
  receiver: 'discord-webhook'

receivers:
- name: 'discord-webhook'
  webhook_configs:
  - url: 'http://localhost:9099'
    send_resolved: true
```

## Support

- GitHub: https://github.com/rogerrum/alertmanager-discord
- Documentation: See README.md and SYSTEMD_GUIDE.md
