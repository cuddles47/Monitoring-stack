#!/bin/bash

set -e

echo "=== Tạo người dùng hệ thống cho Alertmanager ==="
sudo useradd --system --no-create-home --shell /bin/false alertmanager || true

echo "=== Tìm phiên bản mới nhất của Alertmanager ==="
LATEST_VERSION=$(wget -qO- https://api.github.com/repos/prometheus/alertmanager/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
  echo "Không thể tìm phiên bản mới nhất. Thoát."
  exit 1
fi

echo "Đang tải Alertmanager phiên bản $LATEST_VERSION"
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v${LATEST_VERSION}/alertmanager-${LATEST_VERSION}.linux-amd64.tar.gz

echo "=== Giải nén và di chuyển các file cần thiết ==="
tar -xvf alertmanager-${LATEST_VERSION}.linux-amd64.tar.gz
sudo mkdir -p /etc/alertmanager /alertmanager-data
sudo cp alertmanager-${LATEST_VERSION}.linux-amd64/alertmanager /usr/local/bin/
sudo cp alertmanager-${LATEST_VERSION}.linux-amd64/amtool /usr/local/bin/
sudo cp alertmanager-${LATEST_VERSION}.linux-amd64/alertmanager.yml /etc/alertmanager/

echo "=== Thiết lập quyền cho thư mục cấu hình và dữ liệu ==="
sudo chown -R alertmanager:alertmanager /etc/alertmanager /alertmanager-data

echo "=== Tạo systemd service cho Alertmanager ==="
sudo tee /etc/systemd/system/alertmanager.service > /dev/null <<EOF
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/alertmanager \\
  --storage.path=/alertmanager-data \\
  --config.file=/etc/alertmanager/alertmanager.yml

[Install]
WantedBy=multi-user.target
EOF

echo "=== Dọn dẹp tệp tạm ==="
rm -rf alertmanager-${LATEST_VERSION}.linux-amd64*

echo "=== Kiểm tra phiên bản alertmanager đã cài ==="
/usr/local/bin/alertmanager --version || echo "Lỗi khi chạy alertmanager"

echo "=== Bật và khởi động dịch vụ Alertmanager ==="
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable alertmanager
sudo systemctl start alertmanager

echo "=== Kiểm tra trạng thái dịch vụ ==="
sudo systemctl status alertmanager --no-pager
