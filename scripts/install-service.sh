#!/bin/bash

# =============================================================================
# Alertmanager Discord Webhook - Systemd Service Installer
# =============================================================================
# Mô tả: Script để cài đặt alertmanager-discord như systemd service
# Sử dụng: sudo ./install-service.sh [install|uninstall|status]
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SERVICE_NAME="alertmanager-discord"
SERVICE_FILE="$SERVICE_NAME.service"
ENV_FILE="$SERVICE_NAME.env"
SYSTEMD_DIR="/etc/systemd/system"
ENV_DIR="/etc/default"
CURRENT_DIR="$(pwd)"
BINARY_PATH="$CURRENT_DIR/$SERVICE_NAME"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if binary exists
check_binary() {
    if [ ! -f "$BINARY_PATH" ]; then
        log_error "Binary not found at $BINARY_PATH"
        log_info "Please build the binary first: go build -o $SERVICE_NAME ."
        exit 1
    fi
    
    if [ ! -x "$BINARY_PATH" ]; then
        log_error "Binary is not executable"
        log_info "Making binary executable..."
        chmod +x "$BINARY_PATH"
    fi
    
    log_success "Binary found and executable: $BINARY_PATH"
}

# Check if service file exists
check_service_file() {
    if [ ! -f "$SERVICE_FILE" ]; then
        log_error "Service file not found: $SERVICE_FILE"
        log_info "Please create the service file first"
        exit 1
    fi
    
    log_success "Service file found: $SERVICE_FILE"
}

# Install service
install_service() {
    log_info "Installing $SERVICE_NAME systemd service..."
    
    # Check prerequisites
    check_binary
    check_service_file
    
    # Copy service file to systemd directory
    log_info "Copying service file to $SYSTEMD_DIR/"
    cp "$SERVICE_FILE" "$SYSTEMD_DIR/"
    chmod 644 "$SYSTEMD_DIR/$SERVICE_FILE"
    
    # Copy environment file if exists
    if [ -f "$ENV_FILE" ]; then
        log_info "Copying environment file to $ENV_DIR/"
        cp "$ENV_FILE" "$ENV_DIR/$SERVICE_NAME"
        chmod 644 "$ENV_DIR/$SERVICE_NAME"
    else
        log_warning "Environment file $ENV_FILE not found, using service defaults"
    fi
    
    # Reload systemd daemon
    log_info "Reloading systemd daemon..."
    systemctl daemon-reload
    
    # Enable service
    log_info "Enabling $SERVICE_NAME service..."
    systemctl enable "$SERVICE_NAME"
    
    # Start service
    log_info "Starting $SERVICE_NAME service..."
    systemctl start "$SERVICE_NAME"
    
    # Check status
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "$SERVICE_NAME service installed and started successfully"
        
        # Show status
        log_info "Service status:"
        systemctl status "$SERVICE_NAME" --no-pager
        
        log_info "Service logs:"
        journalctl -u "$SERVICE_NAME" -n 10 --no-pager
        
        log_info ""
        log_info "Service management commands:"
        log_info "  sudo systemctl start $SERVICE_NAME     # Start service"
        log_info "  sudo systemctl stop $SERVICE_NAME      # Stop service"
        log_info "  sudo systemctl restart $SERVICE_NAME   # Restart service"
        log_info "  sudo systemctl status $SERVICE_NAME    # Check status"
        log_info "  sudo journalctl -u $SERVICE_NAME -f    # Follow logs"
        log_info ""
        log_info "Configuration files:"
        log_info "  $SYSTEMD_DIR/$SERVICE_FILE           # Service definition"
        log_info "  $ENV_DIR/$SERVICE_NAME               # Environment variables"
        
    else
        log_error "$SERVICE_NAME service failed to start"
        log_info "Check logs: journalctl -u $SERVICE_NAME"
        exit 1
    fi
}

# Uninstall service
uninstall_service() {
    log_info "Uninstalling $SERVICE_NAME systemd service..."
    
    # Stop service if running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "Stopping $SERVICE_NAME service..."
        systemctl stop "$SERVICE_NAME"
    fi
    
    # Disable service
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        log_info "Disabling $SERVICE_NAME service..."
        systemctl disable "$SERVICE_NAME"
    fi
    
    # Remove service file
    if [ -f "$SYSTEMD_DIR/$SERVICE_FILE" ]; then
        log_info "Removing service file..."
        rm -f "$SYSTEMD_DIR/$SERVICE_FILE"
    fi
    
    # Remove environment file
    if [ -f "$ENV_DIR/$SERVICE_NAME" ]; then
        log_info "Removing environment file..."
        rm -f "$ENV_DIR/$SERVICE_NAME"
    fi
    
    # Reload systemd daemon
    log_info "Reloading systemd daemon..."
    systemctl daemon-reload
    
    # Reset failed state
    systemctl reset-failed "$SERVICE_NAME" 2>/dev/null || true
    
    log_success "$SERVICE_NAME service uninstalled successfully"
}

# Show service status
show_status() {
    log_info "$SERVICE_NAME service status:"
    
    if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        systemctl status "$SERVICE_NAME" --no-pager
        
        log_info ""
        log_info "Recent logs:"
        journalctl -u "$SERVICE_NAME" -n 20 --no-pager
    else
        log_warning "$SERVICE_NAME service is not installed"
    fi
}

# Validate configuration
validate_config() {
    log_info "Validating service configuration..."
    
    # Check if Discord webhook is set
    if grep -q "YOUR_WEBHOOK_URL" "$SERVICE_FILE"; then
        log_error "Please update the Discord webhook URL in $SERVICE_FILE"
        exit 1
    fi
    
    # Check if user exists
    if ! id "kewwi" &>/dev/null; then
        log_error "User 'kewwi' does not exist. Please update the User= field in $SERVICE_FILE"
        exit 1
    fi
    
    # Check if working directory exists
    if [ ! -d "/home/kewwi/projects/alertmanager-discord" ]; then
        log_error "Working directory does not exist. Please update the WorkingDirectory= field in $SERVICE_FILE"
        exit 1
    fi
    
    log_success "Service configuration is valid"
}

# Update service configuration
update_config() {
    log_info "Updating service configuration..."
    
    # Backup current service file
    if [ -f "$SYSTEMD_DIR/$SERVICE_FILE" ]; then
        cp "$SYSTEMD_DIR/$SERVICE_FILE" "$SYSTEMD_DIR/$SERVICE_FILE.backup"
        log_info "Backed up current service file"
    fi
    
    # Copy new service file
    cp "$SERVICE_FILE" "$SYSTEMD_DIR/"
    chmod 644 "$SYSTEMD_DIR/$SERVICE_FILE"
    
    # Reload and restart
    systemctl daemon-reload
    systemctl restart "$SERVICE_NAME"
    
    log_success "Service configuration updated and restarted"
}

# Main function
main() {
    case "${1:-install}" in
        "install")
            check_root
            validate_config
            install_service
            ;;
        "uninstall")
            check_root
            uninstall_service
            ;;
        "status")
            show_status
            ;;
        "update")
            check_root
            validate_config
            update_config
            ;;
        "logs")
            journalctl -u "$SERVICE_NAME" -f
            ;;
        *)
            echo "Usage: $0 [install|uninstall|status|update|logs]"
            echo ""
            echo "Commands:"
            echo "  install    - Install and start the systemd service"
            echo "  uninstall  - Stop and remove the systemd service"
            echo "  status     - Show service status and recent logs"
            echo "  update     - Update service configuration and restart"
            echo "  logs       - Follow service logs in real-time"
            echo ""
            echo "Note: install, uninstall, and update commands require sudo"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
