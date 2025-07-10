# Alertmanager Discord Webhook - Makefile
# =============================================================================

# Variables
BINARY_NAME=alertmanager-discord
DOCKER_IMAGE=alertmanager-discord
DOCKER_TAG=latest
GO_VERSION=1.21

# Default target
.DEFAULT_GOAL := help

# Build binary
.PHONY: build
build: ## Build the binary
	@echo "Building $(BINARY_NAME)..."
	go build -o $(BINARY_NAME) .
	@echo "✅ Binary built successfully"

# Build for Linux (useful for cross-compilation)
.PHONY: build-linux
build-linux: ## Build binary for Linux
	@echo "Building $(BINARY_NAME) for Linux..."
	GOOS=linux GOARCH=amd64 go build -o $(BINARY_NAME).linux .
	@echo "✅ Linux binary built successfully"

# Clean build artifacts
.PHONY: clean
clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	rm -f $(BINARY_NAME) $(BINARY_NAME).linux $(BINARY_NAME).darwin
	@echo "✅ Clean completed"

# Deep clean workspace
.PHONY: cleanup
cleanup: ## Deep clean workspace (temp files, cache, etc.)
	@echo "Deep cleaning workspace..."
	./scripts/cleanup.sh
	@echo "✅ Deep cleanup completed"

# Check workspace health
.PHONY: check
check: ## Check workspace health and configuration
	@echo "Checking workspace health..."
	./scripts/check.sh

# Run tests
.PHONY: test
test: ## Run tests
	@echo "Running tests..."
	go test -v ./...
	@echo "✅ Tests completed"

# Run application in development mode
.PHONY: dev
dev: build ## Run in development mode
	@echo "Starting development server..."
	./scripts/start.sh

# Install as systemd service
.PHONY: install
install: build ## Install as systemd service
	@echo "Installing systemd service..."
	sudo ./scripts/install-service.sh install

# Uninstall systemd service
.PHONY: uninstall
uninstall: ## Uninstall systemd service
	@echo "Uninstalling systemd service..."
	sudo ./scripts/install-service.sh uninstall

# Check service status
.PHONY: status
status: ## Check systemd service status
	@echo "Checking service status..."
	sudo systemctl status $(BINARY_NAME) || ./scripts/install-service.sh status

# Follow service logs
.PHONY: logs
logs: ## Follow service logs
	@echo "Following service logs..."
	sudo journalctl -u $(BINARY_NAME) -f

# Test webhook
.PHONY: test-webhook
test-webhook: ## Test webhook endpoint
	@echo "Testing webhook..."
	./scripts/test-webhook.sh

# Test multiple alerts
.PHONY: test-multiple
test-multiple: ## Test multiple alerts handling
	@echo "Testing multiple alerts..."
	./scripts/test-multiple-alerts.sh

# Build Docker image
.PHONY: docker-build
docker-build: ## Build Docker image
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .
	@echo "✅ Docker image built successfully"

# Run Docker container
.PHONY: docker-run
docker-run: docker-build ## Run Docker container
	@echo "Running Docker container..."
	docker run -d \
		--name $(BINARY_NAME) \
		-p 9099:9099 \
		-e DISCORD_WEBHOOK="$(DISCORD_WEBHOOK)" \
		-e DISCORD_USERNAME="AlertBot" \
		-e VERBOSE="ON" \
		$(DOCKER_IMAGE):$(DOCKER_TAG)
	@echo "✅ Docker container started"

# Stop Docker container
.PHONY: docker-stop
docker-stop: ## Stop Docker container
	@echo "Stopping Docker container..."
	docker stop $(BINARY_NAME) || true
	docker rm $(BINARY_NAME) || true
	@echo "✅ Docker container stopped"

# Format code
.PHONY: fmt
fmt: ## Format Go code
	@echo "Formatting code..."
	go fmt ./...
	@echo "✅ Code formatted"

# Lint code
.PHONY: lint
lint: ## Lint Go code
	@echo "Linting code..."
	golangci-lint run || echo "⚠️  golangci-lint not installed, skipping..."

# Security scan
.PHONY: security
security: ## Run security scan
	@echo "Running security scan..."
	gosec ./... || echo "⚠️  gosec not installed, skipping..."

# Generate documentation
.PHONY: docs
docs: ## Generate documentation
	@echo "Generating documentation..."
	godoc -http=:6060 &
	@echo "📚 Documentation available at http://localhost:6060"

# Show project structure
.PHONY: tree
tree: ## Show project structure
	@echo "Project structure:"
	tree -I '.git|vendor|node_modules' || ls -la

# Check dependencies
.PHONY: deps
deps: ## Check and download dependencies
	@echo "Checking dependencies..."
	go mod tidy
	go mod verify
	@echo "✅ Dependencies updated"

# Create release
.PHONY: release
release: clean build-linux ## Create release artifacts
	@echo "Creating release artifacts..."
	mkdir -p release
	cp $(BINARY_NAME).linux release/
	cp config/alertmanager.yaml release/
	cp config/alertmanager-discord.yml release/
	cp scripts/install-service.sh release/
	cp systemd/alertmanager-discord.service release/
	cp systemd/alertmanager-discord.env release/
	tar -czf release/$(BINARY_NAME)-linux-amd64.tar.gz -C release $(BINARY_NAME).linux alertmanager.yaml alertmanager-discord.yml install-service.sh alertmanager-discord.service alertmanager-discord.env
	@echo "✅ Release artifacts created in release/"

# Package for distribution
.PHONY: package
package: ## Create distribution packages
	@echo "Creating distribution packages..."
	./scripts/package.sh $(VERSION)

# Setup development environment
.PHONY: setup
setup: ## Setup development environment
	@echo "Setting up development environment..."
	go mod download
	chmod +x scripts/*.sh
	@echo "✅ Development environment ready"

# Update service configuration
.PHONY: update
update: build ## Update systemd service
	@echo "Updating service configuration..."
	sudo ./scripts/install-service.sh update

# Restart service
.PHONY: restart
restart: ## Restart systemd service
	@echo "Restarting service..."
	sudo systemctl restart $(BINARY_NAME)

# Performance test
.PHONY: perf-test
perf-test: ## Run performance test
	@echo "Running performance test..."
	@for i in {1..10}; do \
		echo "Test $$i/10..."; \
		./scripts/test-simple.sh >/dev/null 2>&1; \
		sleep 1; \
	done
	@echo "✅ Performance test completed"

# Show help
.PHONY: help
help: ## Show this help message
	@echo "Alertmanager Discord Webhook - Available commands:"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make build              # Build the binary"
	@echo "  make install            # Install as systemd service"
	@echo "  make test-webhook       # Test webhook functionality"
	@echo "  make logs               # Follow service logs"
