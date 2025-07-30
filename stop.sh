#!/bin/bash

# Media Server Stack Stop Script
# ===============================

set -e

echo "🛑 Stopping Media Server Stack..."

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
    print_error "Docker is not running."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose > /dev/null 2>&1; then
    if ! docker compose version > /dev/null 2>&1; then
        print_error "Docker Compose is not available."
        exit 1
    fi
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

print_status "Using: $COMPOSE_CMD"

# Parse command line arguments
REMOVE_VOLUMES=false
REMOVE_IMAGES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -i|--images)
            REMOVE_IMAGES=true
            shift
            ;;
        --full)
            REMOVE_VOLUMES=true
            REMOVE_IMAGES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --volumes    Remove all volumes (deletes all data)"
            echo "  -i, --images     Remove all images"
            echo "  --full           Remove volumes and images"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0               Stop all services"
            echo "  $0 -v            Stop and remove all data"
            echo "  $0 --full        Complete cleanup"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Stop services in reverse order
print_status "Stopping services..."

if [ "$REMOVE_VOLUMES" = true ]; then
    print_warning "This will delete ALL data including media files, configurations, and databases!"
    read -p "Are you sure? Type 'yes' to continue: " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        print_status "Operation cancelled."
        exit 0
    fi
    
    print_status "Stopping and removing all containers, networks, and volumes..."
    $COMPOSE_CMD down -v --remove-orphans
    
    print_warning "All data has been removed!"
else
    print_status "Stopping all containers..."
    $COMPOSE_CMD down --remove-orphans
fi

if [ "$REMOVE_IMAGES" = true ]; then
    print_status "Removing all images..."
    $COMPOSE_CMD down --rmi all --remove-orphans
fi

# Clean up dangling Docker resources
print_status "Cleaning up Docker resources..."
docker system prune -f > /dev/null 2>&1 || true

print_success "Media Server Stack stopped successfully!"

if [ "$REMOVE_VOLUMES" = true ]; then
    echo ""
    print_warning "All data has been removed. To start fresh:"
    print_warning "1. Update configuration files if needed"
    print_warning "2. Run ./start.sh to restart the stack"
else
    echo ""
    echo "📊 Start again: ./start.sh"
    echo "📜 View logs:   docker-compose logs [service]"
    echo "🔍 Status:      docker-compose ps"
fi