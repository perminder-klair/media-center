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
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --include-media    Include media files in backup (WARNING: Large size!)"
            echo "  --no-compress      Don't compress the backup"
            echo "  --retention DAYS   Number of days to keep backups (default: 30)"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "This script backs up:"
            echo "  - All configuration files"
            echo "  - Docker Compose files"
            echo "  - Environment configuration"
            echo "  - Service databases"
            echo "  - Media files (if --include-media specified)"
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

# Create restore instructions
cat > "$BACKUP_DIR/RESTORE_INSTRUCTIONS.md" << 'EOF'
# Media Server Stack Restore Instructions

## Prerequisites
1. Docker and Docker Compose installed
2. Proper permissions for the user account
3. Same directory structure as original installation

## Restore Steps

### 1. Stop existing services (if any)
```bash
docker-compose down
```

### 2. Restore configuration files
```bash
# Copy all backed up files to your media-center directory
cp -r config/* /path/to/media-center/config/
cp docker-compose.yml /path/to/media-center/
cp .env /path/to/media-center/
```

### 3. Restore permissions
```bash
# Set proper ownership (adjust PUID/PGID as needed)
chown -R 1000:1000 config data
chmod -R 755 config data
chmod 600 config/traefik/acme.json
```

### 4. Update environment variables
```bash
# Edit .env file and update any changed settings
nano .env
```

### 5. Start services
```bash
./start.sh
```

## Important Notes
- Update DNS/hosts file entries for your domain
- Reconfigure VPN settings if changed
- Update API keys and passwords as needed
- Check service logs for any issues: `docker-compose logs [service]`

## Verification
After restore, verify:
1. All services are running: `docker-compose ps`
2. Web interfaces are accessible
3. Authentication is working
4. Media files are properly mounted
5. Download clients are connecting through VPN
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
echo ""
echo "🔄 To restore: Extract backup and follow RESTORE_INSTRUCTIONS.md"
echo "📋 Service info: backup_info.txt"