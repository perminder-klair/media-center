#!/bin/bash

# Media Server Stack Startup Script
# ==================================

set -e

echo "🎬 Starting Media Server Stack..."

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

# Check if .env file exists
if [ ! -f .env ]; then
    print_error ".env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Load environment variables
source .env

# Validate critical environment variables
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    print_error "DOMAIN and EMAIL must be set in .env file"
    exit 1
fi

# Check VPN configuration if enabled
if [ "$ENABLE_VPN" = "true" ]; then
    if [ -z "$VPN_SERVICE_PROVIDER" ] || [ -z "$OPENVPN_USER" ] || [ -z "$OPENVPN_PASSWORD" ]; then
        print_warning "VPN is enabled but not fully configured. Please update .env file."
        print_warning "You may need to place VPN config files in config/gluetun/"
    fi
fi

# Create necessary directories if they don't exist
print_status "Creating necessary directories..."
mkdir -p config/{jellyfin,radarr,sonarr,lidarr,bazarr,prowlarr,jellyseerr,qbittorrent,traefik,authelia,gluetun,flaresolverr,heimdall,unpackerr}
mkdir -p data/{torrents/{movies,tv,music,books},media/{movies,tv,music,books}}

# Set proper permissions
print_status "Setting proper permissions..."
chown -R $PUID:$PGID config data 2>/dev/null || true
chmod -R 755 config data

# Ensure ACME file has correct permissions
touch config/traefik/acme.json
chmod 600 config/traefik/acme.json

# Start the stack in phases
print_status "Starting Phase 1: Infrastructure (VPN, Proxy, Auth)..."
$COMPOSE_CMD up -d gluetun traefik authelia

# Wait for core services
print_status "Waiting for core services to initialize..."
sleep 30

# Check if Gluetun is healthy (if VPN is enabled)
if [ "$ENABLE_VPN" = "true" ]; then
    print_status "Checking VPN status..."
    for i in {1..12}; do
        if docker exec gluetun wget -qO- ifconfig.me 2>/dev/null; then
            print_success "VPN connection established"
            break
        fi
        if [ $i -eq 12 ]; then
            print_warning "VPN might not be working properly. Check Gluetun logs."
        fi
        sleep 5
    done
fi

print_status "Starting Phase 2: Media Services..."
$COMPOSE_CMD up -d jellyfin jellyseerr

print_status "Starting Phase 3: Content Management (*arr stack)..."
$COMPOSE_CMD up -d prowlarr radarr sonarr lidarr bazarr

print_status "Starting Phase 4: Download & Utility Services..."
$COMPOSE_CMD up -d qbittorrent flaresolverr unpackerr

print_status "Starting Phase 5: Dashboard..."
$COMPOSE_CMD up -d heimdall

print_success "All services started!"

echo ""
echo "🌐 Access URLs (update /etc/hosts or DNS):"
echo "   Dashboard:    https://${DOMAIN}"
echo "   Auth:         https://auth.${DOMAIN}"
echo "   Jellyfin:     https://jellyfin.${DOMAIN}"
echo "   Requests:     https://requests.${DOMAIN}"
echo "   Traefik:      https://dashboard.${DOMAIN}"
echo ""
echo "🔧 Management URLs:"
echo "   Prowlarr:     https://prowlarr.${DOMAIN}"
echo "   Radarr:       https://radarr.${DOMAIN}"
echo "   Sonarr:       https://sonarr.${DOMAIN}"
echo "   Lidarr:       https://lidarr.${DOMAIN}"
echo ""
echo "   Bazarr:       https://bazarr.${DOMAIN}"
echo "   qBittorrent:  https://qbittorrent.${DOMAIN}"
echo ""
echo "📋 Default Login:"
echo "   Username: admin"
echo "   Password: admin123"
echo "   ⚠️  CHANGE THIS IMMEDIATELY!"
echo ""
echo "📊 Status: docker-compose ps"
echo "📜 Logs:   docker-compose logs -f [service]"
echo "🛑 Stop:   ./stop.sh"
echo ""
print_warning "Remember to:"
print_warning "1. Update your DNS or /etc/hosts file to point domains to this server"
print_warning "2. Configure your VPN settings in .env and config/gluetun/"
print_warning "3. Change default passwords in Authelia and all services"
print_warning "4. Configure indexers in Prowlarr"
print_warning "5. Set up quality profiles in *arr applications"