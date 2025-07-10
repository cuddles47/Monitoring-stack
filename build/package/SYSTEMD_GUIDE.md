# Systemd Service Setup Guide

## 📋 Hướng dẫn cài đặt Alertmanager Discord như Systemd Service

### 🚀 Cài đặt nhanh

1. **Build binary (nếu chưa có)**:
```bash
go build -o alertmanager-discord .
```

2. **Cài đặt service**:
```bash
sudo ./install-service.sh install
```

3. **Kiểm tra status**:
```bash
sudo systemctl status alertmanager-discord
```

### 📁 Files được tạo

- `/etc/systemd/system/alertmanager-discord.service` - Service definition
- `/etc/default/alertmanager-discord` - Environment variables
- `/home/kewwi/projects/alertmanager-discord/alertmanager-discord` - Binary

### 🔧 Cấu hình

#### Cách 1: Sửa environment file (Khuyến nghị)
```bash
sudo nano /etc/default/alertmanager-discord
```

#### Cách 2: Sửa service file trực tiếp
```bash
sudo nano /etc/systemd/system/alertmanager-discord.service
sudo systemctl daemon-reload
sudo systemctl restart alertmanager-discord
```

### 📊 Quản lý Service

#### Các lệnh cơ bản:
```bash
# Khởi động service
sudo systemctl start alertmanager-discord

# Dừng service
sudo systemctl stop alertmanager-discord

# Restart service
sudo systemctl restart alertmanager-discord

# Reload configuration
sudo systemctl reload alertmanager-discord

# Check status
sudo systemctl status alertmanager-discord

# Enable auto-start on boot
sudo systemctl enable alertmanager-discord

# Disable auto-start on boot
sudo systemctl disable alertmanager-discord
```

#### Xem logs:
```bash
# Real-time logs
sudo journalctl -u alertmanager-discord -f

# Recent logs
sudo journalctl -u alertmanager-discord -n 50

# Logs since boot
sudo journalctl -u alertmanager-discord -b

# Logs for specific time
sudo journalctl -u alertmanager-discord --since "2025-07-03 10:00:00"
```

### 🔧 Troubleshooting

#### Service không start được:
```bash
# Check detailed status
sudo systemctl status alertmanager-discord -l

# Check logs
sudo journalctl -u alertmanager-discord -n 20

# Check configuration
sudo systemctl cat alertmanager-discord

# Test binary manually
cd /home/kewwi/projects/alertmanager-discord
./alertmanager-discord
```

#### Permission issues:
```bash
# Check file permissions
ls -la /home/kewwi/projects/alertmanager-discord/alertmanager-discord

# Fix permissions
chmod +x /home/kewwi/projects/alertmanager-discord/alertmanager-discord

# Check user exists
id kewwi
```

#### Port already in use:
```bash
# Check what's using the port
sudo ss -tlnp | grep 9099

# Kill process using port
sudo kill $(sudo lsof -t -i:9099)
```

### 🔄 Update Service

#### Update binary:
```bash
# Stop service
sudo systemctl stop alertmanager-discord

# Build new binary
go build -o alertmanager-discord .

# Start service
sudo systemctl start alertmanager-discord
```

#### Update configuration:
```bash
# Edit environment file
sudo nano /etc/default/alertmanager-discord

# Restart service
sudo systemctl restart alertmanager-discord
```

#### Update service definition:
```bash
# Edit local service file
nano alertmanager-discord.service

# Update service
sudo ./install-service.sh update
```

### 🗑️ Gỡ cài đặt

```bash
# Uninstall service completely
sudo ./install-service.sh uninstall

# Verify removal
sudo systemctl status alertmanager-discord
```

### 📊 Monitoring

#### Health check:
```bash
# Check if service is running
systemctl is-active alertmanager-discord

# Check if service is enabled
systemctl is-enabled alertmanager-discord

# Test webhook endpoint
curl -f http://127.0.0.1:9099 || echo "Service not responding"
```

#### Performance monitoring:
```bash
# Resource usage
sudo systemctl show alertmanager-discord --property=MainPID
ps -p $(sudo systemctl show alertmanager-discord --property=MainPID --value) -o pid,ppid,cmd,%mem,%cpu

# Network connections
sudo ss -tulpn | grep $(sudo systemctl show alertmanager-discord --property=MainPID --value)
```

### 🔐 Security Features

Service được cấu hình với các security features:

- **NoNewPrivileges**: Không thể tạo new privileges
- **PrivateTmp**: Private /tmp directory
- **ProtectSystem**: Read-only access to system directories
- **ProtectHome**: No access to home directories (except working directory)
- **RestrictAddressFamilies**: Chỉ allow IPv4/IPv6
- **RestrictNamespaces**: Hạn chế namespace access

### 📝 Configuration Examples

#### High availability setup:
```ini
[Service]
Restart=always
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3
```

#### Custom logging:
```ini
[Service]
StandardOutput=file:/var/log/alertmanager-discord.log
StandardError=file:/var/log/alertmanager-discord-error.log
```

#### Resource limits:
```ini
[Service]
MemoryMax=128M
CPUQuota=50%
TasksMax=100
```

### 🔄 Auto-restart on failure

Service được cấu hình để tự động restart khi có lỗi:

- **Restart=always**: Luôn restart khi process exit
- **RestartSec=10**: Đợi 10 giây trước khi restart
- Systemd sẽ tự động restart service nếu binary crash

### 📈 Production Tips

1. **Log rotation**: Configure logrotate cho journal logs
2. **Monitoring**: Setup monitoring cho service status
3. **Backup**: Backup configuration files
4. **Testing**: Test service restart sau system reboot
5. **Documentation**: Document custom configurations

---

## 🎯 Quick Reference

```bash
# Install service
sudo ./install-service.sh install

# Check status
sudo ./install-service.sh status

# Follow logs
sudo ./install-service.sh logs

# Update service
sudo ./install-service.sh update

# Uninstall service
sudo ./install-service.sh uninstall
```
