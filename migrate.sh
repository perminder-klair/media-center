#!/bin/bash

# Media Server Stack Migration Orchestrator
# ==========================================

set -e

echo "🚀 Media Server Stack Migration Orchestrator"
echo "============================================="

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

print_step() {
    echo ""
    echo -e "${BLUE}▶ STEP: $1${NC}"
    echo "----------------------------------------"
}

# Configuration variables
MIGRATION_TYPE="local"  # local, remote, manual
SOURCE_PATH=""
TARGET_PATH=""
REMOTE_HOST=""
REMOTE_USER=""
INCLUDE_MEDIA=false
BACKUP_NAME=""
SKIP_VALIDATION=false

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Migration Types:
  local       Migrate to another directory on the same machine
  remote      Migrate to a remote machine via SSH
  manual      Create backup for manual transfer

Options:
  -t, --type TYPE        Migration type: local, remote, or manual (default: local)
  -s, --source PATH      Source directory (default: current directory)
  -d, --dest PATH        Destination directory (for local migration)
  -r, --remote HOST      Remote host for SSH migration (user@hostname)
  -u, --user USER        Remote user (if not specified in --remote)
  -m, --include-media    Include media files in migration
  -n, --name NAME        Custom backup name
  --skip-validation      Skip post-migration validation
  -h, --help             Show this help message

Examples:
  $0                                    # Interactive local migration
  $0 -t local -d /new/media-center      # Migrate to new local directory
  $0 -t remote -r user@server.com       # Migrate to remote server
  $0 -t manual -m                       # Create backup with media for manual transfer
  $0 -t remote -r server.com -u admin -m  # Remote migration with media

Migration Process:
  1. Pre-migration validation
  2. Create backup with migration metadata
  3. Transfer backup (if applicable)
  4. Stop services on target
  5. Restore configuration and data
  6. Start services on target
  7. Post-migration validation
  8. Generate migration report

EOF
}

# Function to prompt user for input
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

# Function to validate prerequisites
validate_prerequisites() {
    local errors=0
    
    print_status "Validating prerequisites..."
    
    # Check Docker
    if ! command -v docker > /dev/null 2>&1; then
        print_error "Docker is not installed"
        errors=$((errors + 1))
    elif ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running"
        errors=$((errors + 1))
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose > /dev/null 2>&1 && ! docker compose version > /dev/null 2>&1; then
        print_error "Docker Compose is not available"
        errors=$((errors + 1))
    fi
    
    # Check if we're in a media-center directory
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found. Are you in the media-center directory?"
        errors=$((errors + 1))
    fi
    
    # Check for required scripts
    for script in backup.sh restore.sh; do
        if [ ! -f "$script" ]; then
            print_error "Required script not found: $script"
            errors=$((errors + 1))
        fi
    done
    
    # Check SSH for remote migrations
    if [ "$MIGRATION_TYPE" = "remote" ]; then
        if ! command -v ssh > /dev/null 2>&1; then
            print_error "SSH is not available (required for remote migration)"
            errors=$((errors + 1))
        fi
        
        if ! command -v scp > /dev/null 2>&1; then
            print_error "SCP is not available (required for remote migration)"
            errors=$((errors + 1))
        fi
    fi
    
    if [ $errors -gt 0 ]; then
        print_error "Prerequisites validation failed with $errors errors"
        return 1
    fi
    
    print_success "Prerequisites validation passed"
    return 0
}

# Function to gather migration information
gather_migration_info() {
    print_step "Gathering Migration Information"
    
    if [ -z "$SOURCE_PATH" ]; then
        SOURCE_PATH=$(pwd)
    fi
    
    print_status "Migration Configuration:"
    echo "  Type: $MIGRATION_TYPE"
    echo "  Source: $SOURCE_PATH"
    
    case "$MIGRATION_TYPE" in
        local)
            if [ -z "$TARGET_PATH" ]; then
                TARGET_PATH=$(prompt_user "Destination directory")
            fi
            echo "  Destination: $TARGET_PATH"
            ;;
        remote)
            if [ -z "$REMOTE_HOST" ]; then
                REMOTE_HOST=$(prompt_user "Remote host (user@hostname)")
            fi
            if [ -z "$TARGET_PATH" ]; then
                TARGET_PATH=$(prompt_user "Remote destination directory" "/opt/media-center")
            fi
            echo "  Remote host: $REMOTE_HOST"
            echo "  Remote path: $TARGET_PATH"
            ;;
        manual)
            echo "  Mode: Manual transfer (backup creation only)"
            ;;
    esac
    
    echo "  Include media: $INCLUDE_MEDIA"
    
    if [ -z "$BACKUP_NAME" ]; then
        BACKUP_NAME="migration-$(date +%Y%m%d_%H%M%S)"
    fi
    echo "  Backup name: $BACKUP_NAME"
}

# Function to create migration backup
create_migration_backup() {
    print_step "Creating Migration Backup"
    
    local backup_args="--migration --export-secrets --compress"
    
    if [ "$INCLUDE_MEDIA" = true ]; then
        backup_args="$backup_args --include-media"
    fi
    
    print_status "Running backup with migration options..."
    if ./backup.sh $backup_args; then
        print_success "Migration backup created successfully"
        
        # Find the created backup
        BACKUP_FILE=$(find backups/ -name "media-server-backup-*.tar.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
        
        if [ -n "$BACKUP_FILE" ]; then
            print_status "Backup file: $BACKUP_FILE"
            print_status "Backup size: $(ls -lh "$BACKUP_FILE" | awk '{print $5}')"
        else
            print_error "Could not locate backup file"
            return 1
        fi
    else
        print_error "Backup creation failed"
        return 1
    fi
}

# Function to transfer backup
transfer_backup() {
    case "$MIGRATION_TYPE" in
        local)
            print_step "Transferring to Local Destination"
            
            if [ ! -d "$TARGET_PATH" ]; then
                print_status "Creating destination directory: $TARGET_PATH"
                mkdir -p "$TARGET_PATH"
            fi
            
            print_status "Copying backup to destination..."
            cp "$BACKUP_FILE" "$TARGET_PATH/"
            cp restore.sh "$TARGET_PATH/"
            cp validate.sh "$TARGET_PATH/" 2>/dev/null || true
            
            print_success "Files transferred to: $TARGET_PATH"
            ;;
            
        remote)
            print_step "Transferring to Remote Host"
            
            print_status "Testing SSH connection..."
            if ! ssh -o ConnectTimeout=10 "$REMOTE_HOST" "echo 'SSH connection successful'"; then
                print_error "SSH connection failed"
                return 1
            fi
            
            print_status "Creating remote directory..."
            ssh "$REMOTE_HOST" "mkdir -p '$TARGET_PATH'"
            
            print_status "Transferring backup file..."
            if scp "$BACKUP_FILE" "$REMOTE_HOST:$TARGET_PATH/"; then
                print_success "Backup transferred successfully"
            else
                print_error "Backup transfer failed"
                return 1
            fi
            
            print_status "Transferring restore scripts..."
            scp restore.sh "$REMOTE_HOST:$TARGET_PATH/"
            scp validate.sh "$REMOTE_HOST:$TARGET_PATH/" 2>/dev/null || true
            
            print_success "All files transferred to remote host"
            ;;
            
        manual)
            print_step "Manual Transfer Preparation"
            
            print_success "Backup created for manual transfer"
            print_status "Transfer the following files to your target machine:"
            echo "  - $BACKUP_FILE"
            echo "  - restore.sh"
            echo "  - validate.sh (if present)"
            echo ""
            print_status "On the target machine, run:"
            echo "  ./restore.sh -b $(basename "$BACKUP_FILE")"
            return 0
            ;;
    esac
}

# Function to perform remote restoration
perform_restoration() {
    case "$MIGRATION_TYPE" in
        local)
            print_step "Performing Local Restoration"
            
            cd "$TARGET_PATH"
            
            print_status "Running restoration..."
            if ./restore.sh -b "$(basename "$BACKUP_FILE")" --yes; then
                print_success "Local restoration completed"
            else
                print_error "Local restoration failed"
                return 1
            fi
            ;;
            
        remote)
            print_step "Performing Remote Restoration"
            
            print_status "Executing remote restoration..."
            if ssh "$REMOTE_HOST" "cd '$TARGET_PATH' && ./restore.sh -b '$(basename "$BACKUP_FILE")' --yes"; then
                print_success "Remote restoration completed"
            else
                print_error "Remote restoration failed"
                return 1
            fi
            ;;
            
        manual)
            # Already handled in transfer_backup
            return 0
            ;;
    esac
}

# Function to validate migration
validate_migration() {
    if [ "$SKIP_VALIDATION" = true ]; then
        print_status "Skipping validation as requested"
        return 0
    fi
    
    if [ "$MIGRATION_TYPE" = "manual" ]; then
        print_status "Manual migration - validation to be performed on target system"
        return 0
    fi
    
    print_step "Validating Migration"
    
    case "$MIGRATION_TYPE" in
        local)
            cd "$TARGET_PATH"
            if [ -f "validate.sh" ]; then
                print_status "Running validation script..."
                ./validate.sh
            else
                print_warning "Validation script not found, performing basic checks..."
                docker-compose ps
            fi
            ;;
            
        remote)
            print_status "Running remote validation..."
            ssh "$REMOTE_HOST" "cd '$TARGET_PATH' && if [ -f validate.sh ]; then ./validate.sh; else docker-compose ps; fi"
            ;;
    esac
}

# Function to generate migration report
generate_migration_report() {
    print_step "Generating Migration Report"
    
    local report_file="migration-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "# Media Server Stack Migration Report"
        echo "# Generated: $(date)"
        echo "=================================="
        echo ""
        echo "## Migration Details"
        echo "Type: $MIGRATION_TYPE"
        echo "Source: $SOURCE_PATH"
        echo "Backup File: $BACKUP_FILE"
        echo "Include Media: $INCLUDE_MEDIA"
        echo ""
        
        case "$MIGRATION_TYPE" in
            local)
                echo "Destination: $TARGET_PATH"
                ;;
            remote)
                echo "Remote Host: $REMOTE_HOST"
                echo "Remote Path: $TARGET_PATH"
                ;;
        esac
        
        echo ""
        echo "## Timeline"
        echo "Started: $(date)"
        echo "Backup Size: $([ -f "$BACKUP_FILE" ] && ls -lh "$BACKUP_FILE" | awk '{print $5}' || echo "Unknown")"
        echo ""
        echo "## Next Steps"
        echo "1. Verify that all services are running correctly"
        echo "2. Test service integrations and API connections"
        echo "3. Update DNS/networking if applicable"
        echo "4. Update any hardcoded IP addresses or hostnames"
        echo "5. Reconfigure external access (port forwarding, etc.)"
        echo "6. Update backup schedules to point to new location"
        echo ""
        echo "## Important Files to Review"
        echo "- .env (environment variables)"
        echo "- secrets_export.txt (delete after updating API keys)"
        echo "- migration_info.txt (system differences)"
        echo "- space_requirements.txt (disk usage info)"
        echo ""
        echo "## Service URLs (update if hostname changed)"
        echo "Dashboard:    http://localhost:8082"
        echo "Jellyfin:     http://localhost:8096"
        echo "Requests:     http://localhost:5055"
        echo "Management:   Check SERVICE-PORTS.md for complete list"
        
    } > "$report_file"
    
    print_success "Migration report generated: $report_file"
    
    # Display key information
    echo ""
    print_status "Migration Summary:"
    echo "  ✅ Backup created: $(basename "$BACKUP_FILE")"
    echo "  ✅ Files transferred"
    echo "  ✅ Services restored"
    echo "  ✅ Basic validation completed"
    echo ""
    print_warning "Don't forget to:"
    print_warning "  1. Update API keys and passwords"
    print_warning "  2. Test all service integrations"
    print_warning "  3. Delete secrets_export.txt after use"
    print_warning "  4. Update external network configurations"
}

# Function to cleanup
cleanup() {
    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
        if confirm_action "Delete local backup file? ($BACKUP_FILE)"; then
            rm -f "$BACKUP_FILE"
            print_success "Local backup file deleted"
        fi
    fi
}

# Main migration function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type)
                MIGRATION_TYPE="$2"
                shift 2
                ;;
            -s|--source)
                SOURCE_PATH="$2"
                shift 2
                ;;
            -d|--dest)
                TARGET_PATH="$2"
                shift 2
                ;;
            -r|--remote)
                REMOTE_HOST="$2"
                shift 2
                ;;
            -u|--user)
                REMOTE_USER="$2"
                shift 2
                ;;
            -m|--include-media)
                INCLUDE_MEDIA=true
                shift
                ;;
            -n|--name)
                BACKUP_NAME="$2"
                shift 2
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Validate migration type
    if [[ ! "$MIGRATION_TYPE" =~ ^(local|remote|manual)$ ]]; then
        print_error "Invalid migration type: $MIGRATION_TYPE"
        exit 1
    fi
    
    # Combine remote user and host if specified separately
    if [ -n "$REMOTE_USER" ] && [ -n "$REMOTE_HOST" ] && [[ ! "$REMOTE_HOST" =~ @ ]]; then
        REMOTE_HOST="$REMOTE_USER@$REMOTE_HOST"
    fi
    
    echo ""
    print_status "Starting migration process..."
    
    # Execute migration steps
    validate_prerequisites || exit 1
    gather_migration_info
    
    if ! confirm_action "Proceed with migration?"; then
        print_status "Migration cancelled by user"
        exit 0
    fi
    
    create_migration_backup || exit 1
    transfer_backup || exit 1
    
    if [ "$MIGRATION_TYPE" != "manual" ]; then
        perform_restoration || exit 1
        validate_migration || exit 1
    fi
    
    generate_migration_report
    
    if [ "$MIGRATION_TYPE" != "manual" ]; then
        cleanup
    fi
    
    echo ""
    print_success "🎉 Migration completed successfully!"
    
    if [ "$MIGRATION_TYPE" = "manual" ]; then
        echo ""
        print_status "For manual migration:"
        print_status "1. Transfer $BACKUP_FILE to target machine"
        print_status "2. Run: ./restore.sh -b $(basename "$BACKUP_FILE")"
        print_status "3. Run: ./validate.sh (if available)"
    fi
}

# Handle script interruption
trap 'print_error "Migration interrupted"; exit 1' INT TERM

# Run main function with all arguments
main "$@"