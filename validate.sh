#!/bin/bash

# Media Server Stack Validation Script
# =====================================

set -e

echo "🔍 Media Server Stack Validation"
echo "================================="

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
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Global variables
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0
COMPOSE_CMD=""

# Function to increment test counters
test_result() {
    local result="$1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    case "$result" in
        "pass")
            PASSED_TESTS=$((PASSED_TESTS + 1))
            ;;
        "fail")
            FAILED_TESTS=$((FAILED_TESTS + 1))
            ;;
        "warn")
            WARNING_TESTS=$((WARNING_TESTS + 1))
            ;;
    esac
}

# Function to check if a service is running
check_service_running() {
    local service="$1"
    local container_id=$($COMPOSE_CMD ps -q "$service" 2>/dev/null)
    
    if [ -n "$container_id" ]; then
        local status=$(docker inspect --format='{{.State.Status}}' "$container_id" 2>/dev/null)
        if [ "$status" = "running" ]; then
            return 0
        fi
    fi
    return 1
}

# Function to check service health
check_service_health() {
    local service="$1"
    local container_id=$($COMPOSE_CMD ps -q "$service" 2>/dev/null)
    
    if [ -n "$container_id" ]; then
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null)
        case "$health" in
            "healthy")
                return 0
                ;;
            "unhealthy")
                return 1
                ;;
            *)
                # No health check defined, check if running
                check_service_running "$service"
                return $?
                ;;
        esac
    fi
    return 1
}

# Function to test HTTP endpoint
test_http_endpoint() {
    local service="$1"
    local port="$2"
    local path="${3:-/}"
    local timeout="${4:-10}"
    
    if curl -f -s --max-time "$timeout" "http://localhost:$port$path" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to validate prerequisites
validate_prerequisites() {
    print_status "Validating prerequisites..."
    
    # Check Docker
    print_test "Docker installation and status"
    if command -v docker > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
        print_success "Docker is installed and running"
        test_result "pass"
    else
        print_error "Docker is not available or not running"
        test_result "fail"
        return 1
    fi
    
    # Check Docker Compose
    print_test "Docker Compose availability"
    if command -v docker-compose > /dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
        print_success "Docker Compose found: docker-compose"
        test_result "pass"
    elif docker compose version > /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
        print_success "Docker Compose found: docker compose"
        test_result "pass"
    else
        print_error "Docker Compose not available"
        test_result "fail"
        return 1
    fi
    
    # Check for required files
    print_test "Required configuration files"
    local required_files=("docker-compose.yml" ".env")
    local missing_files=0
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            print_success "$file found"
        else
            print_error "$file missing"
            missing_files=$((missing_files + 1))
        fi
    done
    
    if [ $missing_files -eq 0 ]; then
        test_result "pass"
    else
        test_result "fail"
        return 1
    fi
    
    return 0
}

# Function to validate environment configuration
validate_environment() {
    print_status "Validating environment configuration..."
    
    print_test "Environment variables"
    if [ -f ".env" ]; then
        local required_vars=("PUID" "PGID" "TZ" "DOMAIN" "EMAIL")
        local missing_vars=0
        
        for var in "${required_vars[@]}"; do
            if grep -q "^$var=" .env; then
                local value=$(grep "^$var=" .env | cut -d'=' -f2)
                if [ -n "$value" ]; then
                    print_success "$var is set"
                else
                    print_warning "$var is empty"
                    test_result "warn"
                fi
            else
                print_error "$var is missing"
                missing_vars=$((missing_vars + 1))
            fi
        done
        
        if [ $missing_vars -eq 0 ]; then
            test_result "pass"
        else
            test_result "fail"
        fi
    else
        print_error ".env file not found"
        test_result "fail"
    fi
}

# Function to validate directory structure
validate_directories() {
    print_status "Validating directory structure..."
    
    print_test "Configuration directories"
    local config_dirs=("config" "data")
    local missing_dirs=0
    
    for dir in "${config_dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_success "$dir directory exists"
            
            # Check permissions
            if [ -r "$dir" ] && [ -w "$dir" ]; then
                print_success "$dir directory permissions OK"
            else
                print_warning "$dir directory permissions may be incorrect"
                test_result "warn"
            fi
        else
            print_error "$dir directory missing"
            missing_dirs=$((missing_dirs + 1))
        fi
    done
    
    if [ $missing_dirs -eq 0 ]; then
        test_result "pass"
    else
        test_result "fail"
    fi
    
    # Check data subdirectories
    print_test "Media directories"
    local media_dirs=("data/media" "data/torrents")
    for dir in "${media_dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_success "$dir exists"
        else
            print_warning "$dir missing (will be created by services)"
            test_result "warn"
        fi
    done
}

# Function to validate service status
validate_services() {
    print_status "Validating service status..."
    
    local services=("jellyfin" "jellyseerr" "prowlarr" "radarr" "sonarr" "lidarr" "bazarr" "qbittorrent" "flaresolverr" "unpackerr" "heimdall")
    
    for service in "${services[@]}"; do
        print_test "Service: $service"
        
        if check_service_running "$service"; then
            print_success "$service is running"
            test_result "pass"
            
            # Additional health check if available
            if check_service_health "$service"; then
                print_success "$service is healthy"
            else
                print_warning "$service is running but may not be healthy"
                test_result "warn"
            fi
        else
            print_error "$service is not running"
            test_result "fail"
        fi
    done
}

# Function to validate network connectivity
validate_connectivity() {
    print_status "Validating network connectivity..."
    
    # Define service ports
    declare -A service_ports=(
        ["jellyfin"]="8096"
        ["jellyseerr"]="5055"
        ["prowlarr"]="9696"
        ["radarr"]="7878"
        ["sonarr"]="8989"
        ["lidarr"]="8686"
        ["bazarr"]="6767"
        ["qbittorrent"]="8080"
        ["flaresolverr"]="8191"
        ["heimdall"]="8082"
    )
    
    for service in "${!service_ports[@]}"; do
        local port="${service_ports[$service]}"
        print_test "HTTP connectivity: $service ($port)"
        
        if check_service_running "$service"; then
            # Wait a moment for service to be ready
            sleep 2
            
            if test_http_endpoint "$service" "$port" "/" 5; then
                print_success "$service HTTP endpoint responding"
                test_result "pass"
            else
                print_warning "$service HTTP endpoint not responding (may still be initializing)"
                test_result "warn"
            fi
        else
            print_error "$service not running - skipping connectivity test"
            test_result "fail"
        fi
    done
}

# Function to validate service configurations
validate_configurations() {
    print_status "Validating service configurations..."
    
    # Check Jellyfin config
    print_test "Jellyfin configuration"
    if [ -f "config/jellyfin/config/system.xml" ]; then
        print_success "Jellyfin system configuration found"
        test_result "pass"
    else
        print_warning "Jellyfin system configuration not found (may be first run)"
        test_result "warn"
    fi
    
    # Check *arr configurations
    local arr_services=("radarr" "sonarr" "lidarr" "bazarr" "prowlarr")
    for service in "${arr_services[@]}"; do
        print_test "$service configuration"
        if [ -f "config/$service/config.xml" ]; then
            print_success "$service configuration found"
            test_result "pass"
        else
            print_warning "$service configuration not found (may be first run)"
            test_result "warn"
        fi
    done
    
    # Check qBittorrent config
    print_test "qBittorrent configuration"
    if [ -f "config/qbittorrent/qBittorrent/qBittorrent.conf" ]; then
        print_success "qBittorrent configuration found"
        test_result "pass"
    else
        print_warning "qBittorrent configuration not found (may be first run)"
        test_result "warn"
    fi
}

# Function to validate database integrity
validate_databases() {
    print_status "Validating database integrity..."
    
    # Check for database files
    local db_files=(
        "config/jellyfin/data/jellyfin.db"
        "config/radarr/radarr.db"
        "config/sonarr/sonarr.db"
        "config/lidarr/lidarr.db"
        "config/prowlarr/prowlarr.db"
        "config/bazarr/db/bazarr.db"
        "config/jellyseerr/db/db.sqlite3"
    )
    
    for db_file in "${db_files[@]}"; do
        local service=$(echo "$db_file" | cut -d'/' -f2)
        print_test "$service database"
        
        if [ -f "$db_file" ]; then
            # Basic SQLite integrity check
            if file "$db_file" | grep -q SQLite; then
                print_success "$service database file is valid SQLite"
                test_result "pass"
            else
                print_error "$service database file appears corrupted"
                test_result "fail"
            fi
        else
            print_warning "$service database not found (may be first run)"
            test_result "warn"
        fi
    done
}

# Function to validate media library
validate_media_library() {
    print_status "Validating media library..."
    
    print_test "Media directory structure"
    local media_subdirs=("movies" "tv" "music" "books")
    local existing_dirs=0
    
    for subdir in "${media_subdirs[@]}"; do
        if [ -d "data/media/$subdir" ]; then
            print_success "Media directory exists: $subdir"
            existing_dirs=$((existing_dirs + 1))
        else
            print_warning "Media directory missing: $subdir"
        fi
    done
    
    if [ $existing_dirs -gt 0 ]; then
        test_result "pass"
    else
        test_result "warn"
    fi
    
    # Check for media files (basic count)
    print_test "Media content"
    local media_count=$(find data/media -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mp3" -o -name "*.flac" \) 2>/dev/null | wc -l)
    
    if [ "$media_count" -gt 0 ]; then
        print_success "Found $media_count media files"
        test_result "pass"
    else
        print_warning "No media files found (library may be empty)"
        test_result "warn"
    fi
}

# Function to validate download client
validate_download_client() {
    print_status "Validating download client..."
    
    print_test "qBittorrent connection"
    if check_service_running "qbittorrent"; then
        if test_http_endpoint "qbittorrent" "8080" "/" 10; then
            print_success "qBittorrent web interface accessible"
            test_result "pass"
        else
            print_warning "qBittorrent web interface not responding"
            test_result "warn"
        fi
    else
        print_error "qBittorrent not running"
        test_result "fail"
    fi
    
    # Check download directories
    print_test "Download directories"
    local download_dirs=("data/torrents" "data/torrents/movies" "data/torrents/tv" "data/torrents/music")
    local missing_download_dirs=0
    
    for dir in "${download_dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_success "Download directory exists: $dir"
        else
            print_warning "Download directory missing: $dir"
            missing_download_dirs=$((missing_download_dirs + 1))
        fi
    done
    
    if [ $missing_download_dirs -eq 0 ]; then
        test_result "pass"
    else
        test_result "warn"
    fi
}

# Function to check for common issues
check_common_issues() {
    print_status "Checking for common issues..."
    
    # Check for port conflicts
    print_test "Port conflicts"
    local ports=("8096" "5055" "9696" "7878" "8989" "8686" "6767" "8080" "8191" "8082")
    local conflicts=0
    
    for port in "${ports[@]}"; do
        if netstat -ln 2>/dev/null | grep -q ":$port " || ss -ln 2>/dev/null | grep -q ":$port "; then
            # Port is in use, check if it's our service
            local container_using_port=$($COMPOSE_CMD ps --format "table {{.Names}}\t{{.Ports}}" | grep ":$port->" | awk '{print $1}')
            if [ -n "$container_using_port" ]; then
                print_success "Port $port in use by $container_using_port"
            else
                print_warning "Port $port may be in use by external process"
                conflicts=$((conflicts + 1))
            fi
        fi
    done
    
    if [ $conflicts -eq 0 ]; then
        test_result "pass"
    else
        test_result "warn"
    fi
    
    # Check disk space
    print_test "Disk space"
    local available_space=$(df . | awk 'NR==2 {print $4}')
    local available_space_gb=$((available_space / 1024 / 1024))
    
    if [ "$available_space_gb" -gt 10 ]; then
        print_success "Sufficient disk space available (${available_space_gb}GB)"
        test_result "pass"
    elif [ "$available_space_gb" -gt 5 ]; then
        print_warning "Low disk space (${available_space_gb}GB remaining)"
        test_result "warn"
    else
        print_error "Very low disk space (${available_space_gb}GB remaining)"
        test_result "fail"
    fi
    
    # Check for secrets file (should be deleted after migration)
    print_test "Security cleanup"
    if [ -f "secrets_export.txt" ]; then
        print_warning "secrets_export.txt still exists - delete after updating API keys"
        test_result "warn"
    else
        print_success "No sensitive files found"
        test_result "pass"
    fi
}

# Function to display validation summary
display_summary() {
    echo ""
    echo "============================================="
    echo "📊 Validation Summary"
    echo "============================================="
    echo ""
    
    echo "Total Tests: $TOTAL_TESTS"
    echo "✅ Passed: $PASSED_TESTS"
    echo "⚠️  Warnings: $WARNING_TESTS"
    echo "❌ Failed: $FAILED_TESTS"
    echo ""
    
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    
    if [ $FAILED_TESTS -eq 0 ]; then
        if [ $WARNING_TESTS -eq 0 ]; then
            print_success "🎉 All validations passed! Media center is fully operational."
        else
            print_warning "✅ All critical validations passed with $WARNING_TESTS warnings."
            echo ""
            print_status "Common warnings after migration:"
            print_status "- Services may need time to fully initialize"
            print_status "- API keys may need to be reconfigured"
            print_status "- Empty media directories are normal for new setups"
        fi
    else
        print_error "❌ $FAILED_TESTS critical validation(s) failed."
        echo ""
        print_status "Recommended actions:"
        print_status "1. Check service logs: docker-compose logs [service-name]"
        print_status "2. Verify .env configuration"
        print_status "3. Ensure proper file permissions"
        print_status "4. Check available disk space"
        print_status "5. Restart services: docker-compose restart"
    fi
    
    echo ""
    print_status "Success Rate: ${success_rate}%"
    
    if [ $success_rate -ge 90 ]; then
        echo "🏆 Excellent migration!"
    elif [ $success_rate -ge 80 ]; then
        echo "✅ Good migration with minor issues"
    elif [ $success_rate -ge 70 ]; then
        echo "⚠️  Migration completed but needs attention"
    else
        echo "❌ Migration has significant issues"
    fi
}

# Function to generate detailed report
generate_report() {
    local report_file="validation-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "# Media Server Stack Validation Report"
        echo "# Generated: $(date)"
        echo "======================================="
        echo ""
        echo "## Summary"
        echo "Total Tests: $TOTAL_TESTS"
        echo "Passed: $PASSED_TESTS"
        echo "Warnings: $WARNING_TESTS"
        echo "Failed: $FAILED_TESTS"
        echo "Success Rate: $((PASSED_TESTS * 100 / TOTAL_TESTS))%"
        echo ""
        echo "## System Information"
        echo "Hostname: $(hostname)"
        echo "Date: $(date)"
        echo "Docker Version: $(docker --version 2>/dev/null || echo "Unknown")"
        echo "Compose Command: $COMPOSE_CMD"
        echo ""
        echo "## Service Status"
        $COMPOSE_CMD ps 2>/dev/null || echo "Unable to get service status"
        echo ""
        echo "## Disk Usage"
        df -h .
        echo ""
        echo "## Next Steps"
        if [ $FAILED_TESTS -eq 0 ]; then
            echo "✅ Validation successful - no critical issues found"
        else
            echo "❌ Address failed validations before using the system"
        fi
        echo ""
        echo "Recommended post-migration tasks:"
        echo "1. Update API keys in all *arr applications"
        echo "2. Configure indexers in Prowlarr"
        echo "3. Set up library paths in Jellyfin"
        echo "4. Test download functionality"
        echo "5. Verify external access (if applicable)"
        
    } > "$report_file"
    
    print_success "Detailed report saved: $report_file"
}

# Main validation function
main() {
    local generate_report_flag=false
    local quick_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--report)
                generate_report_flag=true
                shift
                ;;
            -q|--quick)
                quick_mode=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -r, --report    Generate detailed validation report"
                echo "  -q, --quick     Quick validation (skip detailed checks)"
                echo "  -h, --help      Show this help message"
                echo ""
                echo "This script validates:"
                echo "  - Prerequisites and environment"
                echo "  - Service status and health"
                echo "  - Network connectivity"
                echo "  - Configuration integrity"
                echo "  - Database validity"
                echo "  - Media library structure"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
    
    echo ""
    print_status "Starting validation process..."
    echo ""
    
    # Run validation steps
    validate_prerequisites || exit 1
    validate_environment
    validate_directories
    validate_services
    
    if [ "$quick_mode" = false ]; then
        validate_connectivity
        validate_configurations
        validate_databases
        validate_media_library
        validate_download_client
        check_common_issues
    fi
    
    display_summary
    
    if [ "$generate_report_flag" = true ]; then
        generate_report
    fi
    
    # Exit with appropriate code
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function with all arguments
main "$@"