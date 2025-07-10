#!/bin/bash

# =============================================================================
# Alertmanager Discord Webhook - Package Builder
# =============================================================================
# Description: Package binary, config, and service files for deployment
# Usage: ./scripts/package.sh [version]
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_NAME="alertmanager-discord"
VERSION=${1:-"latest"}
BUILD_DIR="build"
PACKAGE_DIR="$BUILD_DIR/package"
RELEASE_DIR="$BUILD_DIR/release"
CURRENT_DIR="$(pwd)"

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

# Clean up previous builds
cleanup() {
    log_info "Cleaning up previous builds..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$PACKAGE_DIR"
    mkdir -p "$RELEASE_DIR"
}

# Build binary for Linux
build_binary() {
    log_info "Building binary for Linux..."
    
    # Build for Linux x86_64
    GOOS=linux GOARCH=amd64 go build -ldflags "-s -w" -o "$PACKAGE_DIR/$PROJECT_NAME" .
    
    # Make binary executable
    chmod +x "$PACKAGE_DIR/$PROJECT_NAME"
    
    log_success "Binary built successfully"
}

# Copy configuration files
copy_configs() {
    log_info "Copying configuration files..."
    
    # Copy systemd service file
    cp "systemd/$PROJECT_NAME.service" "$PACKAGE_DIR/"
    
    # Copy environment template
    cp "systemd/$PROJECT_NAME.env" "$PACKAGE_DIR/"
    
    # Copy example Alertmanager config
    cp "config/alertmanager.yaml" "$PACKAGE_DIR/"
    
    # Copy alertmanager-discord config template
    cp "config/alertmanager-discord.yml" "$PACKAGE_DIR/"
    
    # Copy installation script
    cp "scripts/install-service.sh" "$PACKAGE_DIR/"
    chmod +x "$PACKAGE_DIR/install-service.sh"
    
    log_success "Configuration files copied"
}

# Create documentation
create_docs() {
    log_info "Creating documentation..."
    
    # Copy README and guides
    cp "README.md" "$PACKAGE_DIR/"
    cp "docs/SYSTEMD_GUIDE.md" "$PACKAGE_DIR/"
    cp "LICENSE" "$PACKAGE_DIR/"
    
    # Create installation instructions
    cat > "$PACKAGE_DIR/INSTALL.md" << 'EOF'
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
EOF

    log_success "Documentation created"
}

# Create version info
create_version_info() {
    log_info "Creating version information..."
    
    cat > "$PACKAGE_DIR/VERSION" << EOF
Version: $VERSION
Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Go Version: $(go version | cut -d' ' -f3)
Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
Platform: linux/amd64
EOF

    log_success "Version information created"
}

# Create checksums
create_checksums() {
    log_info "Creating checksums..."
    
    cd "$PACKAGE_DIR"
    
    # Create SHA256 checksums
    sha256sum * > SHA256SUMS
    
    cd "$CURRENT_DIR"
    
    log_success "Checksums created"
}

# Create compressed package
create_package() {
    log_info "Creating compressed package..."
    
    cd "$BUILD_DIR"
    
    # Create tar.gz package
    PACKAGE_NAME="$PROJECT_NAME-$VERSION-linux-amd64.tar.gz"
    tar -czf "$PACKAGE_NAME" -C package .
    
    # Move to release directory
    mv "$PACKAGE_NAME" "release/"
    
    # Create ZIP package for Windows users
    ZIP_NAME="$PROJECT_NAME-$VERSION-linux-amd64.zip"
    (cd package && zip -r "../$ZIP_NAME" .)
    mv "$ZIP_NAME" "release/"
    
    cd "$CURRENT_DIR"
    
    log_success "Packages created:"
    log_info "  - $BUILD_DIR/release/$PACKAGE_NAME"
    log_info "  - $BUILD_DIR/release/$ZIP_NAME"
}

# Create DEB package
create_deb_package() {
    log_info "Creating DEB package..."
    
    DEB_DIR="$BUILD_DIR/deb"
    mkdir -p "$DEB_DIR/DEBIAN"
    mkdir -p "$DEB_DIR/usr/local/bin"
    mkdir -p "$DEB_DIR/etc/systemd/system"
    mkdir -p "$DEB_DIR/etc/default"
    mkdir -p "$DEB_DIR/usr/share/doc/$PROJECT_NAME"
    
    # Copy files to DEB structure
    cp "$PACKAGE_DIR/$PROJECT_NAME" "$DEB_DIR/usr/local/bin/"
    cp "$PACKAGE_DIR/$PROJECT_NAME.service" "$DEB_DIR/etc/systemd/system/"
    cp "$PACKAGE_DIR/$PROJECT_NAME.env" "$DEB_DIR/etc/default/"
    cp "$PACKAGE_DIR/README.md" "$DEB_DIR/usr/share/doc/$PROJECT_NAME/"
    cp "$PACKAGE_DIR/SYSTEMD_GUIDE.md" "$DEB_DIR/usr/share/doc/$PROJECT_NAME/"
    cp "$PACKAGE_DIR/LICENSE" "$DEB_DIR/usr/share/doc/$PROJECT_NAME/"
    
    # Create control file
    cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: $PROJECT_NAME
Version: $VERSION
Section: net
Priority: optional
Architecture: amd64
Maintainer: AlertManager Discord Team <noreply@example.com>
Description: Discord webhook for Prometheus AlertManager
 A production-ready webhook service that forwards Prometheus AlertManager
 notifications to Discord channels with rich formatting and multiple
 delivery options.
Depends: systemd
EOF

    # Create postinst script
    cat > "$DEB_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Reload systemd daemon
systemctl daemon-reload

# Create alertmanager-discord user if not exists
if ! id "alertmanager-discord" &>/dev/null; then
    useradd --system --home-dir /var/lib/alertmanager-discord --create-home --shell /bin/false alertmanager-discord
fi

echo "AlertManager Discord installed successfully!"
echo "Configure /etc/default/alertmanager-discord and then run:"
echo "  sudo systemctl enable alertmanager-discord"
echo "  sudo systemctl start alertmanager-discord"
EOF

    chmod 755 "$DEB_DIR/DEBIAN/postinst"
    
    # Create prerm script
    cat > "$DEB_DIR/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e

# Stop service if running
if systemctl is-active --quiet alertmanager-discord; then
    systemctl stop alertmanager-discord
fi

# Disable service if enabled
if systemctl is-enabled --quiet alertmanager-discord; then
    systemctl disable alertmanager-discord
fi
EOF

    chmod 755 "$DEB_DIR/DEBIAN/prerm"
    
    # Build DEB package
    dpkg-deb --build "$DEB_DIR" "$RELEASE_DIR/$PROJECT_NAME-$VERSION-amd64.deb" 2>/dev/null || {
        log_warning "dpkg-deb not available, skipping DEB package creation"
    }
}

# Show package info
show_package_info() {
    log_info "Package information:"
    echo ""
    
    # Show file sizes
    if [ -d "$RELEASE_DIR" ]; then
        echo "Created packages:"
        ls -lah "$RELEASE_DIR"
        echo ""
    fi
    
    # Show package contents
    echo "Package contents:"
    ls -la "$PACKAGE_DIR"
    echo ""
    
    # Show binary info
    echo "Binary information:"
    file "$PACKAGE_DIR/$PROJECT_NAME"
    echo "Size: $(du -h "$PACKAGE_DIR/$PROJECT_NAME" | cut -f1)"
    echo ""
}

# Main function
main() {
    echo "==============================================="
    echo "AlertManager Discord - Package Builder"
    echo "==============================================="
    echo "Version: $VERSION"
    echo ""
    
    cleanup
    build_binary
    copy_configs
    create_docs
    create_version_info
    create_checksums
    create_package
    create_deb_package
    show_package_info
    
    log_success "Package build completed successfully!"
    echo ""
    log_info "Release packages are available in: $RELEASE_DIR"
    log_info ""
    log_info "To test the package:"
    log_info "  cd /tmp"
    log_info "  tar -xzf $CURRENT_DIR/$RELEASE_DIR/$PROJECT_NAME-$VERSION-linux-amd64.tar.gz"
    log_info "  cd $PROJECT_NAME"
    log_info "  sudo ./install-service.sh install"
}

# Run main function
main "$@"
