# DCGM Exporter setup document by kewwi

# Mục lục

- [DCGM Exporter setup document by kewwi](#dcgm-exporter-setup-document-by-kewwi)
  - [Mục lục](#mục-lục)
  - [Cấu hình máy chủ](#cấu-hình-máy-chủ)
  - [step 1 : Install NVIDIA drivers and CUDA](#step-1--install-nvidia-drivers-and-cuda)
  - [step 2 : Install DCGM](#step-2--install-dcgm)
  - [step 3 : Create a system user for DCGM Exporter](#step-3--create-a-system-user-for-dcgm-exporter)
  - [step 4 : Download DCGM Exporter](#step-4--download-dcgm-exporter)
  - [step 5 : Extract DCGM Exporter from the archive](#step-5--extract-dcgm-exporter-from-the-archive)
  - [step 6 : Move binary to the /usr/local/bin](#step-6--move-binary-to-the-usrlocalbin)
  - [step 7 : Clean up downloaded files](#step-7--clean-up-downloaded-files)
  - [step 8 : Verify that you can run the binary](#step-8--verify-that-you-can-run-the-binary)
  - [step 9 : Check DCGM Exporter help options](#step-9--check-dcgm-exporter-help-options)
  - [step 10 : Create systemd unit file](#step-10--create-systemd-unit-file)
  - [step 11 : Configure DCGM Exporter service](#step-11--configure-dcgm-exporter-service)
  - [step 12 : Enable the DCGM Exporter service](#step-12--enable-the-dcgm-exporter-service)
  - [step 13 : Start the DCGM Exporter](#step-13--start-the-dcgm-exporter)
  - [step 14 : Check the status of DCGM Exporter](#step-14--check-the-status-of-dcgm-exporter)
  - [step 15 : Verify metrics are being collected](#step-15--verify-metrics-are-being-collected)

# Cấu hình máy chủ

================

Phần mềm được cài đặt trên máy chủ có:

- Hệ điều hành: Ubuntu 20.04/22.04 server

- CPU: 4 core (Khuyến nghị 8 core)

- RAM: 16GB (Khuyến nghị 32GB)

- Bộ nhớ: 100GB (Khuyến nghị 200GB)

- GPU: NVIDIA GPU với driver hỗ trợ DCGM

- Cho phép truy cập SSH từ xa.

# Bắt đầu

================

## step 1 : Install NVIDIA drivers and CUDA

```sh

# Update system
sudo apt update && sudo apt upgrade -y

# Install NVIDIA driver
sudo apt install nvidia-driver-530 -y

# Reboot system
sudo reboot

# After reboot, verify GPU is detected
nvidia-smi

```

## step 2 : Install DCGM

```sh

# Add NVIDIA repository
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# Update package list
sudo apt update

# Install DCGM
sudo apt install datacenter-gpu-manager -y

# Start DCGM service
sudo systemctl start nvidia-dcgm
sudo systemctl enable nvidia-dcgm

# Verify DCGM is running
sudo dcgmi discovery -l

```

## step 3 : Create a system user for DCGM Exporter

```sh

sudo useradd --system --no-create-home --shell /bin/false dcgm_exporter

```

## step 4 : Download DCGM Exporter

```sh

# Download latest DCGM Exporter (check for latest version at https://github.com/NVIDIA/dcgm-exporter/releases)
wget https://github.com/NVIDIA/dcgm-exporter/releases/download/3.3.0-3.2.0/dcgm-exporter_3.3.0-3.2.0_linux_x86_64.tar.gz

```

## step 5 : Extract DCGM Exporter from the archive

```sh

tar -xvf dcgm-exporter_3.3.0-3.2.0_linux_x86_64.tar.gz

```

## step 6 : Move binary to the /usr/local/bin

```sh

sudo mv dcgm-exporter /usr/local/bin/

# Set proper permissions
sudo chmod +x /usr/local/bin/dcgm-exporter

```

## step 7 : Clean up downloaded files

```sh

rm -rf dcgm-exporter_3.3.0-3.2.0_linux_x86_64.tar.gz

```

## step 8 : Verify that you can run the binary

```sh

dcgm-exporter --version

```

## step 9 : Check DCGM Exporter help options

```sh

dcgm-exporter --help

```

## step 10 : Create systemd unit file

```sh

sudo vim /etc/systemd/system/dcgm_exporter.service

```

## step 11 : Configure DCGM Exporter service

```yaml

[Unit]
Description=DCGM Exporter
Documentation=https://github.com/NVIDIA/dcgm-exporter
Wants=network-online.target
After=network-online.target nvidia-dcgm.service
Requires=nvidia-dcgm.service
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=dcgm_exporter
Group=dcgm_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/dcgm-exporter \
    --listen=:9400 \
    --collectors=/etc/dcgm-exporter/dcp-metrics-included.csv
Environment=DCGM_EXPORTER_LISTEN=:9400
Environment=DCGM_EXPORTER_KUBERNETES=false

[Install]
WantedBy=multi-user.target

```

## step 12 : Enable the DCGM Exporter service

```sh

sudo systemctl daemon-reload
sudo systemctl enable dcgm_exporter

```

## step 13 : Start the DCGM Exporter

```sh

sudo systemctl start dcgm_exporter

```

## step 14 : Check the status of DCGM Exporter

```sh

sudo systemctl status dcgm_exporter

```

## step 15 : Verify metrics are being collected

```sh

# Check if metrics endpoint is accessible
curl http://localhost:9400/metrics

# Check GPU metrics specifically
curl http://localhost:9400/metrics | grep -i gpu

# Check DCGM connection
sudo dcgmi discovery -l

```
