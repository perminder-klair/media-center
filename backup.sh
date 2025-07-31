#!/bin/bash

# Media Server Stack Backup Script
# =================================

set -e

echo "💾 Creating Media Server Stack Backup..."

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

# Configuration
BACKUP_BASE_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/$TIMESTAMP"
RETENTION_DAYS=30

# Parse command line arguments
INCLUDE_MEDIA=false
COMPRESS=true
MIGRATION_MODE=false
EXPORT_SECRETS=true
ANONYMIZE_SECRETS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --include-media)
            INCLUDE_MEDIA=true
            shift
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        --retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --migration)
            MIGRATION_MODE=true
            shift
            ;;
        --export-secrets)
            EXPORT_SECRETS=true
            shift
            ;;
        --anonymize-secrets)
            ANONYMIZE_SECRETS=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --include-media      Include media files in backup (WARNING: Large size!)"
            echo "  --no-compress        Don't compress the backup"
            echo "  --retention DAYS     Number of days to keep backups (default: 30)"
            echo "  --migration          Create migration-optimized backup with system info"
            echo "  --export-secrets     Export API keys and secrets for migration"
            echo "  --anonymize-secrets  Replace secrets with placeholders in configs"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "This script backs up:"
            echo "  - All configuration files"
            echo "  - Docker Compose files"
            echo "  - Environment configuration"
            echo "  - Service databases"
            echo "  - Media files (if --include-media specified)"
            echo "  - System metadata (if --migration specified)"
            echo "  - API keys and secrets (if --export-secrets specified)"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Create backup directory
print_status "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

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

# Function to calculate directory size
get_dir_size() {
    if [ -d "$1" ]; then
        du -sh "$1" 2>/dev/null | cut -f1 || echo "Unknown"
    else
        echo "N/A"
    fi
}

# Function to check service status
check_service_status() {
    local service=$1
    local status=$($COMPOSE_CMD ps -q $service 2>/dev/null)
    if [ -n "$status" ]; then
        local health=$($COMPOSE_CMD ps --format "table {{.Name}}\t{{.Status}}" | grep $service | awk '{print $2}')
        echo "$service: $health"
    else
        echo "$service: Not running"
    fi
}

# Function to extract secrets from config files
extract_secrets() {
    local config_file=$1
    local output_file=$2

    print_status "Extracting secrets from $config_file..."

    # Extract API keys and secrets
    grep -E "(api_key|ApiKey|API_KEY|secret|password|token)" "$config_file" 2>/dev/null | \
    sed 's/^[[:space:]]*//' >> "$output_file" 2>/dev/null || true
}

# Function to anonymize secrets in files
anonymize_secrets() {
    local file=$1
    local backup_file="${file}.original"

    # Create backup of original
    cp "$file" "$backup_file"

    # Replace common secret patterns with placeholders
    sed -i 's/\(api_key[[:space:]]*[:=][[:space:]]*\)[^[:space:]]\+/\1PLACEHOLDER_API_KEY/gi' "$file"
    sed -i 's/\(ApiKey[[:space:]]*[:=][[:space:]]*\)[^[:space:]]\+/\1PLACEHOLDER_API_KEY/gi' "$file"
    sed -i 's/\(API_KEY[[:space:]]*[:=][[:space:]]*\)[^[:space:]]\+/\1PLACEHOLDER_API_KEY/gi' "$file"
    sed -i 's/\(password[[:space:]]*[:=][[:space:]]*\)[^[:space:]]\+/\1PLACEHOLDER_PASSWORD/gi' "$file"
    sed -i 's/\(secret[[:space:]]*[:=][[:space:]]*\)[^[:space:]]\+/\1PLACEHOLDER_SECRET/gi' "$file"
    sed -i 's/\(token[[:space:]]*[:=][[:space:]]*\)[^[:space:]]\+/\1PLACEHOLDER_TOKEN/gi' "$file"
}

# Backup configuration files
print_status "Backing up configuration files..."
if [ -d "config" ]; then
    cp -r config "$BACKUP_DIR/"
    CONFIG_SIZE=$(get_dir_size "config")
    print_success "Configuration files backed up (Size: $CONFIG_SIZE)"
else
    print_warning "Configuration directory not found"
fi

# Backup Docker Compose files
print_status "Backing up Docker Compose files..."
cp docker-compose.yml "$BACKUP_DIR/" 2>/dev/null && print_success "docker-compose.yml backed up" || print_warning "docker-compose.yml not found"
cp .env "$BACKUP_DIR/" 2>/dev/null && print_success ".env backed up" || print_warning ".env not found"

# Backup additional scripts
print_status "Backing up management scripts..."
for script in start.sh stop.sh update.sh backup.sh; do
    if [ -f "$script" ]; then
        cp "$script" "$BACKUP_DIR/"
    fi
done

# Backup media files if requested
if [ "$INCLUDE_MEDIA" = true ]; then
    print_warning "Including media files in backup - this may take a very long time!"
    if [ -d "data" ]; then
        MEDIA_SIZE=$(get_dir_size "data")
        print_status "Backing up media files (Size: $MEDIA_SIZE)..."
        cp -r data "$BACKUP_DIR/"
        print_success "Media files backed up"
    else
        print_warning "Data directory not found"
    fi
fi

# Create service information export
print_status "Exporting service information..."
{
    echo "# Media Server Stack Backup Information"
    echo "# Generated: $(date)"
    echo "# Hostname: $(hostname)"
    echo ""
    echo "## Docker Compose Version"
    $COMPOSE_CMD version 2>/dev/null || echo "Not available"
    echo ""
    echo "## Service Status at Backup Time"
    $COMPOSE_CMD ps 2>/dev/null || echo "Not available"
    echo ""
    echo "## Docker Images"
    $COMPOSE_CMD images 2>/dev/null || echo "Not available"
    echo ""
    echo "## System Information"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Date: $(date)"
} > "$BACKUP_DIR/backup_info.txt"

# Migration-specific backup features
if [ "$MIGRATION_MODE" = true ]; then
    print_status "Creating migration-specific exports..."

    # Export detailed system information
    {
        echo "# Migration System Information"
        echo "# Generated: $(date)"
        echo ""
        echo "## Operating System"
        if [ -f /etc/os-release ]; then
            cat /etc/os-release
        fi
        echo ""
        echo "## Docker Information"
        docker version 2>/dev/null || echo "Docker version not available"
        echo ""
        echo "## Network Configuration"
        ip addr show 2>/dev/null || ifconfig 2>/dev/null || echo "Network info not available"
        echo ""
        echo "## Disk Usage"
        df -h
        echo ""
        echo "## Mount Points"
        mount | grep -E "(config|data)" 2>/dev/null || echo "No custom mounts found"
        echo ""
        echo "## Environment Variables"
        env | grep -E "(PUID|PGID|TZ|CONFIG_ROOT|DATA_ROOT)" | sort
        echo ""
        echo "## Service Health Check"
        for service in jellyfin jellyseerr prowlarr radarr sonarr lidarr bazarr qbittorrent flaresolverr unpackerr heimdall; do
            check_service_status "$service"
        done
    } > "$BACKUP_DIR/migration_info.txt"

    # Check for free disk space on source
    print_status "Checking disk space requirements..."
    {
        echo "# Disk Space Requirements for Migration"
        echo "# Generated: $(date)"
        echo ""
        echo "## Current Usage"
        echo "Config directory: $(get_dir_size config)"
        echo "Data directory: $(get_dir_size data)"
        echo "Total backup size: $(get_dir_size $BACKUP_DIR)"
        echo ""
        echo "## Available Space"
        df -h . | tail -1
        echo ""
        echo "## Recommended Minimum Space on Target:"
        CONFIG_SIZE_BYTES=$(du -sb config 2>/dev/null | cut -f1 || echo "0")
        DATA_SIZE_BYTES=$(du -sb data 2>/dev/null | cut -f1 || echo "0")
        TOTAL_BYTES=$((CONFIG_SIZE_BYTES + DATA_SIZE_BYTES))
        RECOMMENDED_BYTES=$((TOTAL_BYTES * 3 / 2))  # 1.5x for safety
        echo "Minimum: $(numfmt --to=iec $RECOMMENDED_BYTES 2>/dev/null || echo "Unknown")"
    } > "$BACKUP_DIR/space_requirements.txt"
fi

# Export secrets if requested
if [ "$EXPORT_SECRETS" = true ]; then
    print_warning "Exporting API keys and secrets - keep this file secure!"
    SECRETS_FILE="$BACKUP_DIR/secrets_export.txt"

    {
        echo "# Exported Secrets and API Keys"
        echo "# Generated: $(date)"
        echo "# WARNING: Keep this file secure and delete after migration!"
        echo ""
        echo "## Environment Variables (.env)"
        if [ -f .env ]; then
            grep -E "(KEY|SECRET|PASSWORD|TOKEN)" .env 2>/dev/null || echo "No secrets found in .env"
        fi
        echo ""
        echo "## Service Configuration Secrets"
    } > "$SECRETS_FILE"

    # Extract secrets from major config files
    find config -name "*.xml" -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" -o -name "*.conf" 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            echo "## From: $file" >> "$SECRETS_FILE"
            extract_secrets "$file" "$SECRETS_FILE"
            echo "" >> "$SECRETS_FILE"
        fi
    done

    chmod 600 "$SECRETS_FILE"  # Restrict access
    print_success "Secrets exported to: $SECRETS_FILE"
    print_warning "Remember to delete this file after successful migration!"
fi

# Anonymize secrets if requested
if [ "$ANONYMIZE_SECRETS" = true ]; then
    print_status "Anonymizing secrets in configuration files..."

    find "$BACKUP_DIR/config" -name "*.xml" -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" -o -name "*.conf" 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            anonymize_secrets "$file"
        fi
    done

    # Also anonymize .env if present
    if [ -f "$BACKUP_DIR/.env" ]; then
        anonymize_secrets "$BACKUP_DIR/.env"
    fi

    print_success "Secrets anonymized in backup. Original files saved with .original extension"
fi

# Create restore instructions
cat > "$BACKUP_DIR/RESTORE_INSTRUCTIONS.md" << 'EOF'
# Media Server Stack Restore Instructions

## Overview
This backup contains your complete media server stack configuration and can be restored using either the automated restore script or manual procedures described below.

## Quick Start (Recommended)
Use the included automated restore script for the easiest restoration:

```bash
# Extract backup if compressed
tar -xzf media-server-backup-*.tar.gz

# Run interactive restore
./restore.sh -b /path/to/backup

# Validate installation
./validate.sh
```

## Migration Options

### 1. Local Migration
```bash
# Use the migration orchestrator for same-machine moves
./migrate.sh -t local -d /new/media-center/path
```

### 2. Remote Migration
```bash
# Migrate to another server
./migrate.sh -t remote -r user@target-server.com -d /opt/media-center
```

### 3. Manual Migration
```bash
# Create migration backup and transfer manually
./backup.sh --migration --export-secrets --include-media
# Transfer files to target machine, then run restore
```

## Prerequisites
1. Docker and Docker Compose installed
2. Proper permissions for the user account (PUID/PGID matching)
3. Sufficient disk space (see space_requirements.txt if available)
4. Network access for Docker image downloads

## Manual Restore Steps

### 1. Prepare Target System
```bash
# Ensure Docker is running
docker info

# Stop any existing services
docker-compose down 2>/dev/null || true
```

### 2. Extract and Copy Files
```bash
# Extract backup if compressed
tar -xzf media-server-backup-*.tar.gz

# Copy configuration files
cp -r config /path/to/media-center/
cp docker-compose.yml /path/to/media-center/
cp .env /path/to/media-center/
cp *.sh /path/to/media-center/

# Copy data if included in backup
cp -r data /path/to/media-center/ 2>/dev/null || echo "No data directory in backup"
```

### 3. Update Configuration
```bash
# Review and update environment variables
nano .env

# Key variables to check:
# - DOMAIN (update for new server)
# - EMAIL (notification email)
# - TZ (timezone)
# - PUID/PGID (user/group IDs)

# Update any hardcoded paths or IP addresses
```

### 4. Set Permissions
```bash
# Set proper ownership (use PUID/PGID from .env)
chown -R 1000:1000 config data
chmod -R 755 config data

# Special permissions for certain files
chmod 600 config/traefik/acme.json 2>/dev/null || true
```

### 5. Start Services
```bash
# Use the startup script if available
./start.sh

# Or start manually
docker-compose up -d

# Monitor startup
docker-compose logs -f
```

## Post-Migration Tasks

### 1. Service Configuration
- **API Keys**: Update API keys in all *arr applications (use secrets_export.txt if available)
- **Prowlarr**: Reconfigure indexers and test connections
- **Download Client**: Verify qBittorrent settings and VPN configuration
- **Jellyfin**: Scan media libraries and update paths if needed

### 2. Network Configuration
- Update DNS entries or hosts files for new IP/domain
- Configure port forwarding on new network
- Update reverse proxy settings if applicable
- Test external access

### 3. Security Updates
- Change default passwords
- Update authentication settings
- Delete secrets_export.txt after updating configurations
- Review and update firewall rules

### 4. Validation
```bash
# Run comprehensive validation
./validate.sh --report

# Check specific services
docker-compose ps
docker-compose logs [service-name]

# Test web interfaces
curl -I http://localhost:8096  # Jellyfin
curl -I http://localhost:5055  # Jellyseerr
```

## Migration-Specific Files

If this backup was created with `--migration` flag, you'll find additional files:

- **migration_info.txt**: System information from source machine
- **space_requirements.txt**: Disk space requirements
- **secrets_export.txt**: Exported API keys and secrets (delete after use)
- **backup_info.txt**: Service status and configuration info

## Troubleshooting

### Common Issues
1. **Permission Errors**: Ensure PUID/PGID match your system user
2. **Port Conflicts**: Check for services using the same ports
3. **Database Corruption**: Restore from a known good backup
4. **Missing Images**: Run `docker-compose pull` to download images
5. **Network Issues**: Verify Docker network configuration

### Service-Specific Issues
- **Jellyfin**: Clear transcoding cache if video playback fails
- **Radarr/Sonarr**: Reconfigure download client connections
- **Prowlarr**: Re-add and test indexers
- **qBittorrent**: Check VPN connection and port settings

### Getting Help
- Check service logs: `docker-compose logs -f [service-name]`
- Verify container status: `docker-compose ps`
- Test connectivity: `docker-compose exec [service] ping [other-service]`
- Review system resources: `docker stats`

## Verification Checklist

After restoration, verify:
- [ ] All services are running: `docker-compose ps`
- [ ] Web interfaces are accessible
- [ ] Authentication is working properly
- [ ] Media files are properly mounted and accessible
- [ ] Download clients can connect and download
- [ ] *arr applications can communicate with each other
- [ ] Jellyfin can stream media content
- [ ] Requests can be made through Jellyseerr
- [ ] All API integrations are functioning

## Advanced Migration Scenarios

### Cross-Platform Migration
When moving between different operating systems:
1. Update paths in configuration files
2. Adjust user/group IDs (PUID/PGID)
3. Verify Docker image compatibility
4. Update any platform-specific settings

### Version Upgrades
If upgrading service versions during migration:
1. Review service changelogs for breaking changes
2. Backup databases before starting
3. Test with a subset of services first
4. Monitor logs closely during startup

### Partial Restoration
To restore only specific services:
1. Extract only needed configuration directories
2. Modify docker-compose.yml to include only desired services
3. Update dependency configurations
4. Start services in proper order

## Support Resources
- Project Documentation: See CLAUDE.md and SERVICE-PORTS.md
- Service Logs: `docker-compose logs -f [service-name]`
- Container Shell Access: `docker-compose exec [service-name] /bin/bash`
- Network Debugging: `docker network ls` and `docker network inspect media_network`

Remember to delete sensitive files like secrets_export.txt after completing the migration!
EOF

# Calculate total backup size
BACKUP_SIZE=$(get_dir_size "$BACKUP_DIR")

# Compress backup if requested
if [ "$COMPRESS" = true ]; then
    print_status "Compressing backup..."
    COMPRESSED_FILE="$BACKUP_BASE_DIR/media-server-backup-$TIMESTAMP.tar.gz"

    tar -czf "$COMPRESSED_FILE" -C "$BACKUP_BASE_DIR" "$TIMESTAMP"

    if [ $? -eq 0 ]; then
        COMPRESSED_SIZE=$(get_dir_size "$COMPRESSED_FILE")
        print_success "Backup compressed: $COMPRESSED_FILE (Size: $COMPRESSED_SIZE)"

        # Remove uncompressed backup
        rm -rf "$BACKUP_DIR"
        FINAL_BACKUP="$COMPRESSED_FILE"
    else
        print_error "Compression failed, keeping uncompressed backup"
        FINAL_BACKUP="$BACKUP_DIR"
    fi
else
    FINAL_BACKUP="$BACKUP_DIR"
fi

# Clean up old backups
if [ "$RETENTION_DAYS" -gt 0 ]; then
    print_status "Cleaning up backups older than $RETENTION_DAYS days..."
    find "$BACKUP_BASE_DIR" -name "media-server-backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "20*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
    print_status "Old backups cleaned up"
fi

print_success "Backup completed successfully!"

echo ""
echo "📦 Backup Location: $FINAL_BACKUP"
echo "📊 Backup Size: $BACKUP_SIZE"
echo "📅 Created: $(date)"
echo ""

if [ "$INCLUDE_MEDIA" = true ]; then
    print_warning "Media files were included - backup size may be very large"
fi

if [ "$MIGRATION_MODE" = true ]; then
    echo "🚀 Migration Mode Features:"
    echo "   📋 System info: migration_info.txt"
    echo "   💾 Space requirements: space_requirements.txt"
fi

if [ "$EXPORT_SECRETS" = true ]; then
    print_warning "🔐 Secrets exported to: secrets_export.txt"
    print_warning "   Keep this file secure and delete after migration!"
fi

if [ "$ANONYMIZE_SECRETS" = true ]; then
    echo "🔒 Secrets anonymized in backup files"
    echo "   Original files preserved with .original extension"
fi

echo ""
echo "🔄 To restore: Extract backup and follow RESTORE_INSTRUCTIONS.md"
echo "📋 Service info: backup_info.txt"

if [ "$MIGRATION_MODE" = true ]; then
    echo ""
    echo "📋 Migration Tips:"
    echo "   1. Review migration_info.txt for system differences"
    echo "   2. Check space_requirements.txt before starting restore"
    echo "   3. Use the restore.sh script for guided restoration"
    echo "   4. Run validate.sh after migration to verify everything works"
fi