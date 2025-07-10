#!/bin/bash

# =============================================================================
# Alertmanager Discord Webhook - Development Files Cleanup
# =============================================================================
# Description: Remove development and testing files for production deployment
# Usage: ./cleanup-dev-files.sh
# =============================================================================

set -e

echo "🧹 Cleaning up development files..."

# Remove development test scripts
echo "Removing development test scripts..."
rm -f test-debug.sh
rm -f test-simple.sh
rm -f test-webhook.sh

# Remove development analysis scripts
echo "Removing development analysis scripts..."
rm -f scripts/analyze-data.sh
rm -f scripts/analyze-payload.sh
rm -f scripts/capture-payload.sh
rm -f scripts/monitor-payloads.sh
rm -f scripts/generate-test-payload.sh

# Remove advanced test scripts
echo "Removing advanced test scripts..."
rm -f scripts/test-edge-cases.sh
rm -f scripts/test-multiple-alerts.sh

# Remove development utilities (optional)
echo "Removing development utilities..."
rm -f scripts/check.sh
rm -f scripts/cleanup.sh

# Remove any backup files
echo "Removing backup files..."
find . -name "*.bak" -delete 2>/dev/null || true
find . -name "*~" -delete 2>/dev/null || true

# Remove examples if they exist
if [ -d "examples" ]; then
    echo "Removing examples directory..."
    rm -rf examples/
fi

# Remove any temporary files
echo "Removing temporary files..."
rm -f /tmp/alertmanager-payload-*.json 2>/dev/null || true

echo "✅ Development files cleanup completed!"
echo ""
echo "📋 Files removed:"
echo "  - test-debug.sh"
echo "  - test-simple.sh"
echo "  - test-webhook.sh"
echo "  - scripts/analyze-*.sh"
echo "  - scripts/capture-payload.sh"
echo "  - scripts/monitor-payloads.sh"
echo "  - scripts/generate-test-payload.sh"
echo "  - scripts/test-*.sh"
echo "  - scripts/check.sh"
echo "  - scripts/cleanup.sh"
echo "  - *.bak files"
echo "  - examples/ directory"
echo ""
echo "🚀 Production-ready files retained:"
echo "  - main.go, go.mod (core app)"
echo "  - Dockerfile, Makefile (build)"
echo "  - scripts/install-service.sh (deployment)"
echo "  - scripts/package.sh (packaging)"
echo "  - scripts/deploy.sh (deployment)"
echo "  - systemd/ (service files)"
echo "  - config/ (configuration)"
echo "  - README.md, documentation"
