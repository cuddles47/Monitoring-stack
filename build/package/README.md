Alertmanager Discord Webhook
========

[![Docker Image Version (latest semver)](https://img.shields.io/docker/v/rogerrum/alertmanager-discord)](https://hub.docker.com/r/rogerrum/alertmanager-discord/tags)
[![license](https://img.shields.io/github/license/rogerrum/alertmanager-discord)](https://github.com/rogerrum/alertmanager-discord/blob/main/LICENSE)
[![DockerHub pulls](https://img.shields.io/docker/pulls/rogerrum/alertmanager-discord.svg)](https://hub.docker.com/r/rogerrum/alertmanager-discord/)
[![DockerHub stars](https://img.shields.io/docker/stars/rogerrum/alertmanager-discord.svg)](https://hub.docker.com/r/rogerrum/alertmanager-discord/)
[![GitHub stars](https://img.shields.io/github/stars/rogerrum/alertmanager-discord.svg)](https://github.com/rogerrum/alertmanager-discord)
[![Contributors](https://img.shields.io/github/contributors/rogerrum/alertmanager-discord.svg)](https://github.com/rogerrum/alertmanager-discord/graphs/contributors)

A production-ready webhook service that forwards Prometheus Alertmanager notifications to Discord channels with rich formatting, emojis, and multiple delivery options.

![Discord Alert Example](https://raw.githubusercontent.com/rogerrum/alertmanager-discord/main/.github/demo-img.png)

## ✨ Features

- 🎯 **Rich Discord Integration**: Formatted embeds with colors, emojis, and fields
- 🔄 **Multi-channel Support**: Send to multiple Discord channels simultaneously  
- 🛡️ **Production Ready**: Systemd service, Docker support, comprehensive logging
- ⚡ **Rate Limiting**: Built-in protection against Discord API limits
- 🎨 **Smart Formatting**: Auto-truncation, emoji indicators, severity colors
- 📊 **Dual Notifications**: Works alongside existing Slack/email notifications
- 🔒 **Security**: Comprehensive systemd security hardening
- 📈 **Monitoring**: Health checks, metrics, structured logging

## 🚀 Quick Start

### Option 1: Systemd Service (Recommended)

```bash
# 1. Build binary
go build -o alertmanager-discord .

# 2. Install as systemd service
sudo ./scripts/install-service.sh install

# 3. Check status
sudo systemctl status alertmanager-discord
```

### Option 2: Docker

```bash
docker run -d \
  --name alertmanager-discord \
  -p 9099:9099 \
  -e DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_WEBHOOK" \
  -e DISCORD_USERNAME="AlertBot" \
  rogerrum/alertmanager-discord
```

### Option 3: Manual Run

```bash
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_WEBHOOK"
export DISCORD_USERNAME="AlertBot"
export LISTEN_ADDRESS="127.0.0.1:9099"
./alertmanager-discord
```

## 📋 Configuration

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `DISCORD_WEBHOOK` | Discord webhook URL | ✅ | - |
| `DISCORD_USERNAME` | Bot display name | ✅ | - |
| `ADDITIONAL_DISCORD_WEBHOOKS` | Additional webhooks (comma-separated) | ❌ | - |
| `DISCORD_AVATAR_URL` | Bot avatar URL | ❌ | - |
| `LISTEN_ADDRESS` | Server listen address | ❌ | 127.0.0.1:9099 |
| `VERBOSE` | Enable verbose logging | ❌ | OFF |

### Alertmanager Configuration

Add webhook to your `alertmanager.yml`:

```yaml
route:
  receiver: 'multi-notifications'

receivers:
- name: 'multi-notifications'
  # Keep existing Slack notifications
  slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK'
    channel: '#monitoring'
    send_resolved: true
    
  # Add Discord notifications
  webhook_configs:
  - url: 'http://localhost:9099'
    send_resolved: true
```

## 🏗️ Project Structure

```
alertmanager-discord/
├── main.go                    # Main application
├── detect-misconfig.go       # Misconfiguration detection
├── Dockerfile                # Docker build
├── go.mod                    # Go module
├── config/
│   └── alertmanager.yaml     # Example alertmanager config
├── scripts/
│   ├── install-service.sh    # Systemd service installer
│   ├── deploy.sh            # Production deployment
│   ├── start.sh             # Development runner
│   ├── test-webhook.sh      # Webhook testing
│   └── test-simple.sh       # Simple test
├── systemd/
│   ├── alertmanager-discord.service  # Systemd service file
│   └── alertmanager-discord.env      # Environment template
├── docs/
│   ├── SYSTEMD_GUIDE.md     # Systemd setup guide
│   └── TEMPLATE.md          # Development template
└── examples/
    └── main_clean.go        # Clean code example
```

## 🔧 Management Commands

### Systemd Service

```bash
# Service management
sudo systemctl start alertmanager-discord
sudo systemctl stop alertmanager-discord
sudo systemctl restart alertmanager-discord
sudo systemctl status alertmanager-discord

# Logs
sudo journalctl -u alertmanager-discord -f

# Configuration
sudo nano /etc/default/alertmanager-discord
```

### Development

```bash
# Run development
./scripts/start.sh

# Test webhook
./scripts/test-webhook.sh

# Follow logs
./scripts/logs
```

## 📊 Alert Format

Discord messages include:

- **Header**: `[FIRING] 🔥 High CPU Usage` 
- **Individual Alerts**: Each alert sent as separate message with:
  - Summary and description (truncated to 200 chars)
  - Severity indicators (🔥 critical, ⚠️ warning, ℹ️ info, 💚 resolved)
  - Key labels and annotations (max 4 labels shown)
  - Timestamps and source links
- **Colors**: Red (firing), Green (resolved), Grey (other)
- **Smart Chunking**: Multiple alerts split into separate messages to avoid Discord limits
- **Rate Limiting**: 200ms delay between messages to prevent API rate limits

### Message Size Limits

- **Title**: Max 150 characters
- **Description**: Max 200 characters  
- **Field Value**: Max 150 characters
- **Total Message**: Max 5000 characters
- **Embeds**: Max 2 per message
- **Labels**: Max 4 shown per alert

## 🧪 Testing

```bash
# Test webhook endpoint
curl -X POST http://localhost:9099 \
  -H "Content-Type: application/json" \
  -d '{"receiver":"test","status":"firing","alerts":[{"status":"firing","labels":{"alertname":"TestAlert","severity":"warning"},"annotations":{"summary":"Test alert","description":"This is a test"}}]}'

# Integration tests
./scripts/test-webhook.sh

# Test multiple alerts handling
./scripts/test-multiple-alerts.sh
```

## 🐳 Docker Deployment

```yaml
version: '3.8'
services:
  alertmanager-discord:
    image: rogerrum/alertmanager-discord
    ports:
      - "9099:9099"
    environment:
      - DISCORD_WEBHOOK=${DISCORD_WEBHOOK}
      - DISCORD_USERNAME=AlertBot
      - VERBOSE=ON
    restart: always
```

## 📚 Documentation

- [Systemd Setup Guide](docs/SYSTEMD_GUIDE.md) - Complete systemd service setup
- [Development Template](docs/TEMPLATE.md) - Code structure and examples
- [Alertmanager Config](config/alertmanager.yaml) - Example configuration

## 🔒 Security

Production deployment includes:

- Systemd security hardening (NoNewPrivileges, ProtectSystem, etc.)
- Network restrictions (RestrictAddressFamilies)
- Process limits and resource constraints
- Read-only system protection
- Private temporary directories

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Original inspiration from [benjojo/alertmanager-discord](https://github.com/benjojo/alertmanager-discord)
- Prometheus and Alertmanager communities
- Discord API documentation

---

**Need help?** Check the [documentation](docs/) or open an issue!
