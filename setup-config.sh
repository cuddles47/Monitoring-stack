#!/bin/bash

# =============================================================================
# Alertmanager Discord Webhook - Configuration Setup Script
# =============================================================================
# Mô tả: Script để thiết lập cấu hình an toàn cho alertmanager-discord
# Sử dụng: ./setup-config.sh
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if template files exist
check_templates() {
    if [ ! -f "alertmanager-discord.env.template" ]; then
        log_error "Template file alertmanager-discord.env.template not found"
        exit 1
    fi
    
    if [ ! -f "alertmanager.yaml.template" ]; then
        log_error "Template file alertmanager.yaml.template not found"
        exit 1
    fi
}

# Setup environment configuration
setup_env_config() {
    log_info "Setting up environment configuration..."
    
    if [ -f "alertmanager-discord.env" ]; then
        log_warning "alertmanager-discord.env already exists"
        read -p "Do you want to overwrite it? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_info "Skipping environment configuration"
            return
        fi
    fi
    
    # Copy template
    cp alertmanager-discord.env.template alertmanager-discord.env
    
    # Prompt for Discord webhook
    echo ""
    log_info "Please enter your Discord webhook URL:"
    log_info "You can get this from Discord Server Settings > Integrations > Webhooks"
    read -p "Discord Webhook URL: " discord_webhook
    
    if [ -n "$discord_webhook" ]; then
        sed -i "s|DISCORD_WEBHOOK=.*|DISCORD_WEBHOOK=$discord_webhook|" alertmanager-discord.env
        log_success "Discord webhook configured"
    else
        log_warning "No webhook URL provided, you'll need to edit alertmanager-discord.env manually"
    fi
    
    # Prompt for username
    read -p "Discord Bot Username (default: AlertBot): " discord_username
    if [ -n "$discord_username" ]; then
        sed -i "s|DISCORD_USERNAME=.*|DISCORD_USERNAME=$discord_username|" alertmanager-discord.env
    fi
    
    # Prompt for listen address
    read -p "Listen Address (default: 127.0.0.1:9099): " listen_address
    if [ -n "$listen_address" ]; then
        sed -i "s|LISTEN_ADDRESS=.*|LISTEN_ADDRESS=$listen_address|" alertmanager-discord.env
    fi
    
    log_success "Environment configuration created: alertmanager-discord.env"
}

# Setup alertmanager configuration
setup_alertmanager_config() {
    log_info "Setting up Alertmanager configuration..."
    
    if [ -f "alertmanager.yaml" ]; then
        log_warning "alertmanager.yaml already exists"
        read -p "Do you want to overwrite it? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_info "Skipping Alertmanager configuration"
            return
        fi
    fi
    
    # Copy template
    cp alertmanager.yaml.template alertmanager.yaml
    
    # Prompt for Slack webhook (optional)
    echo ""
    log_info "Slack configuration (optional - press Enter to skip):"
    read -p "Slack Webhook URL: " slack_webhook
    
    if [ -n "$slack_webhook" ]; then
        sed -i "s|https://hooks.slack.com/services/YOUR_SLACK_WORKSPACE/YOUR_CHANNEL/YOUR_TOKEN|$slack_webhook|" alertmanager.yaml
        log_success "Slack webhook configured"
    else
        log_info "Slack configuration skipped"
    fi
    
    log_success "Alertmanager configuration created: alertmanager.yaml"
}

# Set proper permissions
set_permissions() {
    log_info "Setting file permissions..."
    
    chmod 600 alertmanager-discord.env 2>/dev/null || true
    chmod 644 alertmanager.yaml 2>/dev/null || true
    
    log_success "File permissions set"
}

# Show next steps
show_next_steps() {
    echo ""
    log_info "Configuration setup completed!"
    echo ""
    log_info "Next steps:"
    log_info "1. Review and edit alertmanager-discord.env if needed"
    log_info "2. Review and edit alertmanager.yaml if needed"
    log_info "3. Run the installation script: sudo ./install-service.sh"
    log_info "4. Test the configuration: make test"
    echo ""
    log_warning "Important:"
    log_warning "- Never commit alertmanager-discord.env to version control"
    log_warning "- Keep your webhook URLs and API keys secure"
    log_warning "- Use environment variables in production"
}

# Main function
main() {
    log_info "Alertmanager Discord Webhook - Configuration Setup"
    echo ""
    
    check_templates
    setup_env_config
    setup_alertmanager_config
    set_permissions
    show_next_steps
}

# Run main function
main "$@"
