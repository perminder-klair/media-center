#!/bin/bash

# Media Server Stack Restore Script
# ==================================

set -e

echo "🔄 Media Server Stack Restore Script"
echo "===================================="

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

# Function to prompt for user input
prompt_user() {
    local message="$1"
    local default="$2"
    local response
    
    if [ -n "$default" ]; then
        echo -n "$message [$default]: "
    else
        echo -n "$message: "
    fi
    
    read -r response
    echo "${response:-$default}"
}

# Function to confirm action
confirm_action() {
    local message="$1"
    local response
    
    echo -n "$message (y/N): "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker > /dev/null 2>&1; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose > /dev/null 2>&1; then
        if ! docker compose version > /dev/null 2>&1; then
            print_error "Docker Compose is not available. Please install it."
            exit 1
        fi
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    print_success "Prerequisites check passed"
    return 0
}

# Function to validate backup file
validate_backup() {
    local backup_path="$1"
    
    print_status "Validating backup file: $backup_path"
    
    if [ ! -f "$backup_path" ] && [ ! -d "$backup_path" ]; then
        print_error "Backup not found: $backup_path"
        return 1
    fi
    
    # If it's a compressed file, check if it's valid
    if [[ "$backup_path" == *.tar.gz ]]; then
        if ! tar -tzf "$backup_path" > /dev/null 2>&1; then
            print_error "Invalid tar.gz file: $backup_path"
            return 1
        fi
    fi
    
    print_success "Backup validation passed"
    return 0
}

# Function to extract backup
extract_backup() {
    local backup_path="$1"
    local extract_dir="$2"
    
    print_status "Extracting backup..."
    
    if [[ "$backup_path" == *.tar.gz ]]; then
        mkdir -p "$extract_dir"
        if tar -xzf "$backup_path" -C "$extract_dir" --strip-components=1; then
            print_success "Backup extracted to: $extract_dir"
        else
            print_error "Failed to extract backup"
            return 1
        fi
    elif [ -d "$backup_path" ]; then
        cp -r "$backup_path"/* "$extract_dir/"
        print_success "Backup copied to: $extract_dir"
    else
        print_error "Unsupported backup format"
        return 1
    fi
    
    return 0
}

# Function to check disk space
check_disk_space() {
    local backup_dir="$1"
    
    print_status "Checking disk space requirements..."
    
    if [ -f "$backup_dir/space_requirements.txt" ]; then
        echo ""
        print_status "Space requirements from backup:"
        cat "$backup_dir/space_requirements.txt"
        echo ""
    fi
    
    # Check current available space
    local available_space=$(df . | awk 'NR==2 {print $4}')
    local available_space_human=$(df -h . | awk 'NR==2 {print $4}')
    
    print_status "Available space on current directory: $available_space_human"
    
    # Calculate backup size
    if [ -d "$backup_dir/config" ]; then
        local config_size=$(du -s "$backup_dir/config" 2>/dev/null | awk '{print $1}')
        local data_size=$(du -s "$backup_dir/data" 2>/dev/null | awk '{print $1}' || echo "0")
        local total_size=$((config_size + data_size))
        
        if [ "$total_size" -gt "$available_space" ]; then
            print_error "Insufficient disk space!"
            print_error "Required: $(numfmt --to=iec $((total_size * 1024)))"
            print_error "Available: $available_space_human"
            return 1
        fi
    fi
    
    print_success "Disk space check passed"
    return 0
}

# Function to stop existing services
stop_existing_services() {
    print_status "Checking for existing services..."
    
    if [ -f "docker-compose.yml" ]; then
        if confirm_action "Stop existing services?"; then
            print_status "Stopping existing services..."
            $COMPOSE_CMD down --remove-orphans || true
            print_success "Existing services stopped"
        fi
    fi
}

# Function to backup current configs
backup_existing_configs() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ -d "config" ] || [ -d "data" ] || [ -f ".env" ]; then
        if confirm_action "Backup existing configuration before restore?"; then
            print_status "Creating backup of existing configuration..."
            mkdir -p "backups/pre-restore-$timestamp"
            
            [ -d "config" ] && cp -r config "backups/pre-restore-$timestamp/"
            [ -d "data" ] && cp -r data "backups/pre-restore-$timestamp/"
            [ -f ".env" ] && cp .env "backups/pre-restore-$timestamp/"
            [ -f "docker-compose.yml" ] && cp docker-compose.yml "backups/pre-restore-$timestamp/"
            
            print_success "Existing configuration backed up to: backups/pre-restore-$timestamp"
        fi
    fi
}

# Function to restore files
restore_files() {
    local backup_dir="$1"
    
    print_status "Restoring files from backup..."
    
    # Restore configuration files
    if [ -d "$backup_dir/config" ]; then
        print_status "Restoring configuration files..."
        rm -rf config 2>/dev/null || true
        cp -r "$backup_dir/config" .
        print_success "Configuration files restored"
    fi
    
    # Restore Docker Compose files
    if [ -f "$backup_dir/docker-compose.yml" ]; then
        cp "$backup_dir/docker-compose.yml" .
        print_success "docker-compose.yml restored"
    fi
    
    if [ -f "$backup_dir/.env" ]; then
        cp "$backup_dir/.env" .
        print_success ".env restored"
    fi
    
    # Restore management scripts
    for script in start.sh stop.sh update.sh backup.sh; do
        if [ -f "$backup_dir/$script" ]; then
            cp "$backup_dir/$script" .
            chmod +x "$script"
        fi
    done
    
    # Restore data if present
    if [ -d "$backup_dir/data" ]; then
        if confirm_action "Restore media data? (This may take a long time)"; then
            print_status "Restoring media data..."
            rm -rf data 2>/dev/null || true
            cp -r "$backup_dir/data" .
            print_success "Media data restored"
        fi
    fi
}

# Function to update environment variables
update_environment() {
    print_status "Reviewing environment variables..."
    
    if [ -f ".env" ]; then
        echo ""
        print_status "Current environment variables that may need updating:"
        grep -E "(DOMAIN|EMAIL|PUID|PGID|TZ)" .env 2>/dev/null || true
        echo ""
        
        if confirm_action "Update environment variables interactively?"; then
            # Update key variables
            current_domain=$(grep "^DOMAIN=" .env | cut -d'=' -f2 2>/dev/null || echo "")
            new_domain=$(prompt_user "Domain name" "$current_domain")
            sed -i "s/^DOMAIN=.*/DOMAIN=$new_domain/" .env
            
            current_email=$(grep "^EMAIL=" .env | cut -d'=' -f2 2>/dev/null || echo "")
            new_email=$(prompt_user "Email address" "$current_email")
            sed -i "s/^EMAIL=.*/EMAIL=$new_email/" .env
            
            current_tz=$(grep "^TZ=" .env | cut -d'=' -f2 2>/dev/null || echo "")
            new_tz=$(prompt_user "Timezone" "$current_tz")
            sed -i "s/^TZ=.*/TZ=$new_tz/" .env
            
            print_success "Environment variables updated"
        fi
    else
        print_warning ".env file not found. You may need to create one based on .env.example"
    fi
}

# Function to set permissions
set_permissions() {
    print_status "Setting proper permissions..."
    
    # Get PUID/PGID from .env or use defaults
    local puid=$(grep "^PUID=" .env 2>/dev/null | cut -d'=' -f2 || echo "1000")
    local pgid=$(grep "^PGID=" .env 2>/dev/null | cut -d'=' -f2 || echo "1000")
    
    if [ -d "config" ]; then
        chown -R "$puid:$pgid" config 2>/dev/null || {
            print_warning "Could not set ownership. You may need to run as root or adjust permissions manually."
        }
        chmod -R 755 config
    fi
    
    if [ -d "data" ]; then
        chown -R "$puid:$pgid" data 2>/dev/null || {
            print_warning "Could not set ownership for data directory."
        }
        chmod -R 755 data
    fi
    
    # Special permission for Traefik certificate file
    if [ -f "config/traefik/acme.json" ]; then
        chmod 600 config/traefik/acme.json
    fi
    
    print_success "Permissions set"
}

# Function to restore secrets
restore_secrets() {
    local backup_dir="$1"
    
    if [ -f "$backup_dir/secrets_export.txt" ]; then
        echo ""
        print_warning "Secrets export file found: $backup_dir/secrets_export.txt"
        print_warning "Review this file and manually update API keys in service configurations"
        echo ""
        
        if confirm_action "Display secrets file for review?"; then
            echo ""
            cat "$backup_dir/secrets_export.txt"
            echo ""
        fi
        
        print_warning "Remember to:"
        print_warning "1. Update API keys in *arr applications"
        print_warning "2. Reconfigure service connections"
        print_warning "3. Delete the secrets_export.txt file after restoration"
    fi
}

# Function to start services
start_services() {
    print_status "Starting services..."
    
    if [ -f "start.sh" ]; then
        if confirm_action "Use start.sh script to start services?"; then
            ./start.sh
            return $?
        fi
    fi
    
    # Manual startup
    if confirm_action "Start services manually with docker-compose?"; then
        $COMPOSE_CMD up -d
        print_success "Services started"
        
        # Show service status
        echo ""
        print_status "Service status:"
        $COMPOSE_CMD ps
    fi
}

# Function to display completion info
show_completion_info() {
    echo ""
    print_success "🎉 Restore completed!"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Wait a few minutes for services to fully initialize"
    echo "2. Check service status: $COMPOSE_CMD ps"
    echo "3. View logs if needed: $COMPOSE_CMD logs -f [service-name]"
    echo "4. Access services via their web interfaces"
    echo "5. Reconfigure API keys and service connections"
    echo "6. Run ./validate.sh to verify everything is working"
    echo ""
    echo "🌐 Default Access URLs:"
    echo "   Dashboard:    http://localhost:8082"
    echo "   Jellyfin:     http://localhost:8096"
    echo "   Requests:     http://localhost:5055"
    echo ""
    echo "⚠️  Important:"
    echo "   - Update passwords and API keys"
    echo "   - Test all service integrations"
    echo "   - Monitor logs for any errors"
}

# Main restore function
main() {
    local backup_path=""
    local interactive=true
    local force=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--backup)
                backup_path="$2"
                shift 2
                ;;
            -y|--yes)
                interactive=false
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -b, --backup PATH    Path to backup file or directory"
                echo "  -y, --yes           Non-interactive mode (use defaults)"
                echo "  -f, --force         Force restore without confirmations"
                echo "  -h, --help          Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                                    # Interactive restore"
                echo "  $0 -b backup.tar.gz                  # Restore from specific backup"
                echo "  $0 -b /path/to/backup/dir --yes       # Non-interactive restore"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Interactive backup selection if not provided
    if [ -z "$backup_path" ] && [ "$interactive" = true ]; then
        echo ""
        print_status "Available backups:"
        ls -la backups/ 2>/dev/null || {
            print_error "No backups directory found"
            exit 1
        }
        echo ""
        backup_path=$(prompt_user "Enter backup path (file or directory)")
    fi
    
    if [ -z "$backup_path" ]; then
        print_error "No backup path specified"
        exit 1
    fi
    
    # Start restore process
    check_prerequisites
    validate_backup "$backup_path"
    
    # Extract backup to temporary directory
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    extract_backup "$backup_path" "$TEMP_DIR"
    check_disk_space "$TEMP_DIR"
    
    if [ "$interactive" = true ] && [ "$force" = false ]; then
        stop_existing_services
        backup_existing_configs
    fi
    
    restore_files "$TEMP_DIR"
    
    if [ "$interactive" = true ]; then
        update_environment
        restore_secrets "$TEMP_DIR"
    fi
    
    set_permissions
    
    if [ "$interactive" = true ]; then
        start_services
    fi
    
    show_completion_info
}

# Run main function with all arguments
main "$@"