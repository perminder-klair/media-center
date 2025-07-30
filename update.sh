#!/bin/bash

# Media Server Stack Update Script
# =================================

set -e

echo "🔄 Updating Media Server Stack..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose > /dev/null 2>&1; then
    if ! docker compose version > /dev/null 2>&1; then
        print_error "Docker Compose is not available. Please install it and try again."
        exit 1
    fi
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

print_status "Using: $COMPOSE_CMD"

# Parse command line arguments
BACKUP_CONFIGS=true
AUTO_RESTART=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-backup)
            BACKUP_CONFIGS=false
            shift
            ;;
        --restart)
            AUTO_RESTART=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-backup     Skip configuration backup"
            echo "  --restart       Automatically restart services after update"
            echo "  -h, --help      Show this help message"
            echo ""
            echo "This script will:"
            echo "  1. Backup configurations (unless --no-backup)"
            echo "  2. Pull latest container images"
            echo "  3. Recreate containers with new images"
            echo "  4. Clean up old images and containers"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Create backup if requested
if [ "$BACKUP_CONFIGS" = true ]; then
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    print_status "Creating configuration backup in $BACKUP_DIR..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup configuration directories
    if [ -d "config" ]; then
        cp -r config "$BACKUP_DIR/"
        print_success "Configuration files backed up"
    fi
    
    # Backup compose files
    cp docker-compose.yml "$BACKUP_DIR/" 2>/dev/null || true
    cp .env "$BACKUP_DIR/" 2>/dev/null || true
    
    print_success "Backup created in $BACKUP_DIR"
fi

# Get list of running services
print_status "Checking running services..."
RUNNING_SERVICES=$($COMPOSE_CMD ps --services --filter "status=running" 2>/dev/null || true)

if [ -n "$RUNNING_SERVICES" ]; then
    print_status "Services currently running: $(echo $RUNNING_SERVICES | tr '\n' ' ')"
else
    print_status "No services currently running"
fi

# Pull latest images
print_status "Pulling latest container images..."
$COMPOSE_CMD pull

# Check if any images were updated
UPDATED_IMAGES=$($COMPOSE_CMD images --quiet | xargs docker inspect --format '{{.Id}} {{.RepoTags}}' | wc -l)

if [ "$UPDATED_IMAGES" -gt 0 ]; then
    print_success "Images updated successfully"
    
    # Recreate containers with new images
    print_status "Recreating containers with updated images..."
    $COMPOSE_CMD up -d --force-recreate
    
    # Wait for services to stabilize
    print_status "Waiting for services to stabilize..."
    sleep 30
    
    # Check service health
    print_status "Checking service health..."
    UNHEALTHY_SERVICES=$($COMPOSE_CMD ps --filter "health=unhealthy" --services 2>/dev/null || true)
    
    if [ -n "$UNHEALTHY_SERVICES" ]; then
        print_warning "Some services may be unhealthy: $UNHEALTHY_SERVICES"
        print_warning "Check logs with: docker-compose logs [service_name]"
    else
        print_success "All services appear healthy"
    fi
    
else
    print_status "No image updates available"
fi

# Clean up old images and containers
print_status "Cleaning up old Docker resources..."
docker image prune -f > /dev/null 2>&1 || true
docker container prune -f > /dev/null 2>&1 || true

print_success "Update completed successfully!"

# Show current status
echo ""
print_status "Current service status:"
$COMPOSE_CMD ps

echo ""
echo "📊 Service Status: docker-compose ps"
echo "📜 View Logs:     docker-compose logs -f [service]"
echo "🔄 Restart:       docker-compose restart [service]"

if [ "$BACKUP_CONFIGS" = true ]; then
    echo "💾 Backup Location: $BACKUP_DIR"
fi