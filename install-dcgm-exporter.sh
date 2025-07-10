#!/bin/bash

# DCGM Exporter Installation Script
# Author: kewwi
# Description: Automated installation script for DCGM Exporter on Ubuntu

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DCGM_EXPORTER_VERSION="3.3.0-3.2.0"
DCGM_EXPORTER_USER="dcgm_exporter"
DCGM_EXPORTER_PORT="9400"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Function to check if NVIDIA GPU is present
check_nvidia_gpu() {
    print_status "Checking for NVIDIA GPU..."
    if command_exists nvidia-smi; then
        if nvidia-smi >/dev/null 2>&1; then
            print_success "NVIDIA GPU detected"
            nvidia-smi --query-gpu=name --format=csv,noheader
        else
            print_error "NVIDIA GPU detected but nvidia-smi failed. Please check your NVIDIA driver installation."
            exit 1
        fi
    else
        print_error "nvidia-smi not found. Please install NVIDIA drivers first."
        exit 1
    fi
}

# Function to install NVIDIA drivers
install_nvidia_drivers() {
    print_status "Installing NVIDIA drivers..."
    
    # Update system
    sudo apt update && sudo apt upgrade -y
    
    # Install NVIDIA driver
    sudo apt install nvidia-driver-530 -y
    
    print_warning "System needs to reboot to complete NVIDIA driver installation."
    print_warning "After reboot, run this script again with --skip-nvidia flag"
    read -p "Do you want to reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    else
        print_warning "Please reboot manually and run the script again."
        exit 0
    fi
}

# Function to install DCGM
install_dcgm() {
    print_status "Installing DCGM..."
    
    # Add NVIDIA repository
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -fsSL https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
    
    # Update package list
    sudo apt update
    
    # Install DCGM
    sudo apt install datacenter-gpu-manager -y
    
    # Start and enable DCGM service
    sudo systemctl start nvidia-dcgm
    sudo systemctl enable nvidia-dcgm
    
    # Verify DCGM is running
    print_status "Verifying DCGM installation..."
    if sudo dcgmi discovery -l >/dev/null 2>&1; then
        print_success "DCGM installed and running successfully"
        sudo dcgmi discovery -l
    else
        print_error "DCGM installation failed or not running properly"
        exit 1
    fi
}

# Function to create system user
create_system_user() {
    print_status "Creating system user for DCGM Exporter..."
    
    if id "$DCGM_EXPORTER_USER" &>/dev/null; then
        print_warning "User $DCGM_EXPORTER_USER already exists"
    else
        sudo useradd --system --no-create-home --shell /bin/false "$DCGM_EXPORTER_USER"
        print_success "User $DCGM_EXPORTER_USER created"
    fi
}

# Function to download and install DCGM Exporter
install_dcgm_exporter() {
    print_status "Downloading DCGM Exporter..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download DCGM Exporter
    DOWNLOAD_URL="https://github.com/NVIDIA/dcgm-exporter/releases/download/${DCGM_EXPORTER_VERSION}/dcgm-exporter_${DCGM_EXPORTER_VERSION}_linux_x86_64.tar.gz"
    
    if wget "$DOWNLOAD_URL"; then
        print_success "DCGM Exporter downloaded successfully"
    else
        print_error "Failed to download DCGM Exporter"
        exit 1
    fi
    
    # Extract archive
    print_status "Extracting DCGM Exporter..."
    tar -xvf "dcgm-exporter_${DCGM_EXPORTER_VERSION}_linux_x86_64.tar.gz"
    
    # Move binary to /usr/local/bin
    print_status "Installing DCGM Exporter binary..."
    sudo mv dcgm-exporter /usr/local/bin/
    sudo chmod +x /usr/local/bin/dcgm-exporter
    
    # Clean up
    cd /
    rm -rf "$TEMP_DIR"
    
    print_success "DCGM Exporter installed successfully"
    
    # Verify installation
    if dcgm-exporter --version >/dev/null 2>&1; then
        print_success "DCGM Exporter verification successful"
        dcgm-exporter --version
    else
        print_error "DCGM Exporter verification failed"
        exit 1
    fi
}

# Function to create systemd service
create_systemd_service() {
    print_status "Creating systemd service file..."
    
    sudo tee /etc/systemd/system/dcgm_exporter.service > /dev/null <<EOF
[Unit]
Description=DCGM Exporter
Documentation=https://github.com/NVIDIA/dcgm-exporter
Wants=network-online.target
After=network-online.target nvidia-dcgm.service
Requires=nvidia-dcgm.service
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=$DCGM_EXPORTER_USER
Group=$DCGM_EXPORTER_USER
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/dcgm-exporter \\
    --listen=:$DCGM_EXPORTER_PORT \\
    --collectors=/etc/dcgm-exporter/dcp-metrics-included.csv
Environment=DCGM_EXPORTER_LISTEN=:$DCGM_EXPORTER_PORT
Environment=DCGM_EXPORTER_KUBERNETES=false

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Systemd service file created"
}

# Function to start and enable service
start_service() {
    print_status "Starting DCGM Exporter service..."
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Enable service
    sudo systemctl enable dcgm_exporter
    
    # Start service
    sudo systemctl start dcgm_exporter
    
    # Check service status
    sleep 2
    if sudo systemctl is-active --quiet dcgm_exporter; then
        print_success "DCGM Exporter service started successfully"
        sudo systemctl status dcgm_exporter --no-pager
    else
        print_error "DCGM Exporter service failed to start"
        sudo systemctl status dcgm_exporter --no-pager
        exit 1
    fi
}

# Function to verify metrics
verify_metrics() {
    print_status "Verifying metrics collection..."
    
    sleep 5  # Wait for service to fully start
    
    if curl -s "http://localhost:$DCGM_EXPORTER_PORT/metrics" >/dev/null; then
        print_success "Metrics endpoint is accessible"
        print_status "Sample GPU metrics:"
        curl -s "http://localhost:$DCGM_EXPORTER_PORT/metrics" | grep -i "DCGM_FI_DEV_NAME" | head -5
    else
        print_error "Metrics endpoint is not accessible"
        print_status "Checking if port $DCGM_EXPORTER_PORT is in use:"
        sudo netstat -tulpn | grep ":$DCGM_EXPORTER_PORT"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-nvidia    Skip NVIDIA driver installation"
    echo "  --skip-dcgm      Skip DCGM installation"
    echo "  --help           Show this help message"
    echo ""
    echo "Example:"
    echo "  $0                    # Full installation"
    echo "  $0 --skip-nvidia     # Skip NVIDIA driver installation"
}

# Main installation function
main() {
    local skip_nvidia=false
    local skip_dcgm=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-nvidia)
                skip_nvidia=true
                shift
                ;;
            --skip-dcgm)
                skip_dcgm=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_status "Starting DCGM Exporter installation..."
    
    # Check if running as root
    check_root
    
    # Install NVIDIA drivers if not skipped
    if [[ "$skip_nvidia" == false ]]; then
        if ! command_exists nvidia-smi; then
            install_nvidia_drivers
        else
            check_nvidia_gpu
        fi
    else
        check_nvidia_gpu
    fi
    
    # Install DCGM if not skipped
    if [[ "$skip_dcgm" == false ]]; then
        install_dcgm
    fi
    
    # Create system user
    create_system_user
    
    # Install DCGM Exporter
    install_dcgm_exporter
    
    # Create systemd service
    create_systemd_service
    
    # Start and enable service
    start_service
    
    # Verify metrics
    verify_metrics
    
    print_success "DCGM Exporter installation completed successfully!"
    print_status "Service is running on port $DCGM_EXPORTER_PORT"
    print_status "You can check metrics at: http://localhost:$DCGM_EXPORTER_PORT/metrics"
}

# Run main function with all arguments
main "$@"
