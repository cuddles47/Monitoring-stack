#!/bin/bash

# =============================================================================
# Alertmanager Discord Webhook - Production Deployment Script
# =============================================================================
# Mô tả: Script để build và deploy alertmanager-discord webhook service
# Sử dụng: ./scripts/deploy.sh [development|production]
# =============================================================================

set -e  # Exit on any error

# Configuration
PROJECT_NAME="alertmanager-discord"
DOCKER_IMAGE="$PROJECT_NAME"
DOCKER_TAG="latest"
ENV=${1:-development}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check required tools
check_requirements() {
    log_info "Checking requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    # Check Go (if building locally)
    if ! command -v go &> /dev/null; then
        log_warning "Go is not installed - Docker build only"
    fi
    
    log_success "All requirements satisfied"
}

# Load environment configuration
load_environment() {
    log_info "Loading $ENV environment configuration..."
    
    case $ENV in
        "development")
            ENV_FILE=".env.development"
            COMPOSE_FILE="docker-compose.dev.yml"
            ;;
        "production")
            ENV_FILE=".env.production"
            COMPOSE_FILE="docker-compose.prod.yml"
            ;;
        *)
            log_error "Unknown environment: $ENV. Use 'development' or 'production'"
            exit 1
            ;;
    esac
    
    if [ -f "$ENV_FILE" ]; then
        export $(cat $ENV_FILE | xargs)
        log_success "Environment loaded from $ENV_FILE"
    else
        log_warning "Environment file $ENV_FILE not found, using defaults"
    fi
}

# Validate required environment variables
validate_config() {
    log_info "Validating configuration..."
    
    REQUIRED_VARS=("DISCORD_WEBHOOK" "DISCORD_USERNAME")
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    # Validate Discord webhook URL format
    if [[ ! $DISCORD_WEBHOOK =~ ^https://discord(app)?\.com/api/webhooks/[0-9]{18,19}/[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid Discord webhook URL format"
        exit 1
    fi
    
    log_success "Configuration validation passed"
}

# Build Go binary locally
build_binary() {
    log_info "Building Go binary..."
    
    if command -v go &> /dev/null; then
        # Clean previous builds
        rm -f $PROJECT_NAME
        
        # Build binary
        CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o $PROJECT_NAME .
        
        if [ -f "$PROJECT_NAME" ]; then
            log_success "Binary built successfully"
        else
            log_error "Binary build failed"
            exit 1
        fi
    else
        log_warning "Go not available, skipping binary build"
    fi
}

# Build Docker image
build_docker() {
    log_info "Building Docker image..."
    
    # Build image
    docker build -t $DOCKER_IMAGE:$DOCKER_TAG .
    
    if [ $? -eq 0 ]; then
        log_success "Docker image built successfully"
    else
        log_error "Docker build failed"
        exit 1
    fi
    
    # Show image info
    docker images | grep $DOCKER_IMAGE
}

# Run tests
run_tests() {
    log_info "Running tests..."
    
    # Unit tests
    if command -v go &> /dev/null; then
        go test -v ./...
        if [ $? -eq 0 ]; then
            log_success "Unit tests passed"
        else
            log_error "Unit tests failed"
            exit 1
        fi
    fi
    
    # Integration tests with Docker
    log_info "Running integration tests..."
    
    # Start test container
    docker run -d --name ${PROJECT_NAME}-test \
        -p 9199:9099 \
        -e DISCORD_WEBHOOK="$DISCORD_WEBHOOK" \
        -e DISCORD_USERNAME="TestBot" \
        -e VERBOSE="ON" \
        $DOCKER_IMAGE:$DOCKER_TAG
    
    # Wait for container to start
    sleep 5
    
    # Test webhook endpoint
    TEST_PAYLOAD='{"receiver":"test","status":"firing","alerts":[{"status":"firing","labels":{"alertname":"TestAlert","severity":"warning"},"annotations":{"summary":"Test alert","description":"Integration test"},"startsAt":"2025-07-03T10:00:00Z"}],"commonLabels":{"alertname":"TestAlert"},"commonAnnotations":{"summary":"Test alert"},"externalURL":"http://test:9093"}'
    
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST http://localhost:9199 \
        -H "Content-Type: application/json" \
        -d "$TEST_PAYLOAD")
    
    # Cleanup test container
    docker stop ${PROJECT_NAME}-test
    docker rm ${PROJECT_NAME}-test
    
    if [ "$HTTP_STATUS" == "200" ]; then
        log_success "Integration tests passed"
    else
        log_error "Integration tests failed (HTTP $HTTP_STATUS)"
        exit 1
    fi
}

# Deploy application
deploy_app() {
    log_info "Deploying application in $ENV mode..."
    
    case $ENV in
        "development")
            deploy_development
            ;;
        "production")
            deploy_production
            ;;
    esac
}

# Development deployment
deploy_development() {
    log_info "Starting development deployment..."
    
    # Create development docker-compose if not exists
    if [ ! -f "docker-compose.dev.yml" ]; then
        create_dev_compose
    fi
    
    # Start services
    docker-compose -f docker-compose.dev.yml up -d
    
    log_success "Development environment started"
    log_info "Services available at:"
    log_info "  - Alertmanager Discord: http://localhost:9099"
    log_info "  - Prometheus: http://localhost:9090"
    log_info "  - Alertmanager: http://localhost:9093"
}

# Production deployment
deploy_production() {
    log_info "Starting production deployment..."
    
    # Create production docker-compose if not exists
    if [ ! -f "docker-compose.prod.yml" ]; then
        create_prod_compose
    fi
    
    # Pull latest images
    docker-compose -f docker-compose.prod.yml pull
    
    # Start services with restart policy
    docker-compose -f docker-compose.prod.yml up -d --remove-orphans
    
    # Health check
    sleep 10
    health_check
    
    log_success "Production deployment completed"
}

# Create development docker-compose
create_dev_compose() {
    cat > docker-compose.dev.yml << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus-dev
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./config/alert-rules.yml:/etc/prometheus/alert-rules.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager-dev
    ports:
      - "9093:9093"
    volumes:
      - ./config/alertmanager.yaml:/etc/alertmanager/alertmanager.yml
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    restart: unless-stopped

  alertmanager-discord:
    build: .
    container_name: alertmanager-discord-dev
    ports:
      - "9099:9099"
    environment:
      - DISCORD_WEBHOOK=\${DISCORD_WEBHOOK}
      - DISCORD_USERNAME=\${DISCORD_USERNAME:-AlertBot-Dev}
      - LISTEN_ADDRESS=0.0.0.0:9099
      - VERBOSE=ON
    depends_on:
      - alertmanager
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter-dev
    ports:
      - "9100:9100"
    command:
      - '--path.rootfs=/host'
    volumes:
      - '/:/host:ro,rslave'
    restart: unless-stopped
EOF
    
    log_success "Development docker-compose.yml created"
}

# Create production docker-compose
create_prod_compose() {
    cat > docker-compose.prod.yml << EOF
version: '3.8'

services:
  alertmanager-discord:
    build: .
    container_name: alertmanager-discord-prod
    ports:
      - "9099:9099"
    environment:
      - DISCORD_WEBHOOK=\${DISCORD_WEBHOOK}
      - DISCORD_USERNAME=\${DISCORD_USERNAME:-AlertBot}
      - LISTEN_ADDRESS=0.0.0.0:9099
      - VERBOSE=\${VERBOSE:-OFF}
    volumes:
      - ./logs:/app/logs
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9099/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  default:
    driver: bridge
EOF
    
    log_success "Production docker-compose.yml created"
}

# Health check
health_check() {
    log_info "Performing health check..."
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s http://localhost:9099 > /dev/null 2>&1; then
            log_success "Health check passed"
            return 0
        fi
        
        attempt=$((attempt + 1))
        log_info "Health check attempt $attempt/$max_attempts..."
        sleep 2
    done
    
    log_error "Health check failed after $max_attempts attempts"
    return 1
}

# Show status
show_status() {
    log_info "Application status:"
    docker-compose ps
    
    log_info "Logs:"
    docker-compose logs --tail=20 alertmanager-discord
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    
    # Stop containers
    docker-compose down
    
    # Remove unused images
    docker image prune -f
    
    log_success "Cleanup completed"
}

# Main deployment flow
main() {
    log_info "Starting deployment process for $PROJECT_NAME in $ENV mode..."
    
    # Check requirements
    check_requirements
    
    # Load environment
    load_environment
    
    # Validate configuration
    validate_config
    
    # Build components
    build_binary
    build_docker
    
    # Run tests
    if [ "$ENV" == "production" ]; then
        run_tests
    fi
    
    # Deploy application
    deploy_app
    
    # Show final status
    show_status
    
    log_success "Deployment completed successfully!"
    log_info "Use './scripts/deploy.sh cleanup' to remove all containers"
}

# Handle script arguments
case "${1:-deploy}" in
    "cleanup")
        cleanup
        ;;
    "status")
        show_status
        ;;
    "test")
        run_tests
        ;;
    "development"|"production"|"deploy")
        main
        ;;
    *)
        echo "Usage: $0 [development|production|cleanup|status|test]"
        echo ""
        echo "Commands:"
        echo "  development  - Deploy in development mode with full stack"
        echo "  production   - Deploy in production mode with minimal services"
        echo "  cleanup      - Stop and remove all containers"
        echo "  status       - Show application status"
        echo "  test         - Run integration tests"
        exit 1
        ;;
esac
