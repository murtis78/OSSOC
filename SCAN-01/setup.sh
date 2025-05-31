#!/bin/bash

# Setup script for vulnerability scanning environment
# Creates directory structure and sets permissions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root. Consider using a non-root user with docker group membership."
    fi
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        missing_deps+=("docker")
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        missing_deps+=("docker-compose")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install the missing dependencies and try again."
        exit 1
    fi
    
    log_success "All dependencies found"
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."
    
    local directories=(
        "data/openvas"
        "data/vulnwhisperer"
        "data/nmap-reports/xml"
        "data/nmap-reports/json"
        "data/nmap-reports/html"
        "data/redis"
        "configs/openvas"
        "configs/vulnwhisperer"
        "configs/nmap"
        "certs"
        "secrets"
        "modules/nmap/scripts"
        "modules/nmap/nse_scripts"
        "modules/scheduler"
        "backups"
        "logs"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "Created directory: $dir"
        else
            log_info "Directory already exists: $dir"
        fi
    done
    
    log_success "Directory structure created"
}

# Set permissions
set_permissions() {
    log_info "Setting permissions..."
    
    # Set data directory permissions
    chmod 755 data/
    chmod 755 data/*/
    
    # Set config permissions
    chmod 644 configs/openvas/openvas.conf 2>/dev/null || true
    chmod 644 configs/vulnwhisperer/config.ini 2>/dev/null || true
    
    # Set script permissions
    chmod +x modules/nmap/scripts/*.sh 2>/dev/null || true
    chmod +x modules/nmap/scripts/*.py 2>/dev/null || true
    chmod +x modules/scheduler/*.sh 2>/dev/null || true
    
    # Set secrets directory permissions
    chmod 700 secrets/
    
    log_success "Permissions set"
}

# Generate SSL certificates
generate_certificates() {
    log_info "Generating SSL certificates..."
    
    local cert_dir="certs"
    
    if [ ! -f "$cert_dir/server.crt" ] || [ ! -f "$cert_dir/server.key" ]; then
        # Generate private key
        openssl genrsa -out "$cert_dir/server.key" 2048 2>/dev/null || {
            log_warning "OpenSSL not found, skipping certificate generation"
            return 0
        }
        
        # Generate certificate
        openssl req -new -x509 -key "$cert_dir/server.key" -out "$cert_dir/server.crt" \
            -days 365 -subj "/C=FR/ST=IDF/L=Montigny/O=VulnScan/CN=openvas" 2>/dev/null
        
        chmod 600 "$cert_dir/server.key"
        chmod 644 "$cert_dir/server.crt"
        
        log_success "SSL certificates generated"
    else
        log_info "SSL certificates already exist"
    fi
}

# Create additional configuration files
create_additional_configs() {
    log_info "Creating additional configuration files..."
    
    # Create Nmap configuration
    cat > configs/nmap/nmap.conf << 'EOF'
# Nmap Configuration
# Global settings for Nmap scanner

# Timing template (0-5, 5 is fastest but less reliable)
timing = 3

# Maximum number of hosts to scan in parallel
max_hostgroup = 50

# Maximum number of port scan probe retransmissions
max_retries = 3

# Probe timeout
host_timeout = 900

# Scan delay (milliseconds)
scan_delay = 0

# Maximum scan delay (milliseconds)  
max_scan_delay = 1000

# Source port for scans
source_port = 0

# Interface to use for scanning
interface = 

# Data directory for Nmap
datadir = /usr/share/nmap

# NSE script directory
scriptdir = /usr/share/nmap/scripts

# Default scripts to run
default_scripts = default,vuln,safe
EOF

    # Create targets file template
    cat > data/nmap-reports/targets.txt << 'EOF'
# Nmap Scan Targets
# One target per line, comments start with #
# Examples:
# 192.168.1.0/24
# 10.0.0.1-10.0.0.100
# scanme.nmap.org
# google.com

# Default targets (edit as needed)
192.168.1.0/24
EOF

    # Create Docker health check script
    cat > modules/health-check.sh << 'EOF'
#!/bin/bash
# Health check script for all services

check_openvas() {
    curl -f http://localhost:9392 >/dev/null 2>&1
}

check_vulnwhisperer() {
    # Check if VulnWhisperer process is running
    docker exec vulnwhisperer pgrep -f vulnwhisperer >/dev/null 2>&1
}

check_nmap() {
    # Check if Nmap container is running
    docker exec nmap-scanner nmap --version >/dev/null 2>&1
}

echo "=== Service Health Check ==="
echo -n "OpenVAS: "
if check_openvas; then
    echo "✓ Healthy"
else
    echo "✗ Unhealthy"
fi

echo -n "VulnWhisperer: "
if check_vulnwhisperer; then
    echo "✓ Healthy"
else
    echo "✗ Unhealthy"
fi

echo -n "Nmap: "
if check_nmap; then
    echo "✓ Healthy"
else
    echo "✗ Unhealthy"
fi
EOF
    
    chmod +x modules/health-check.sh
    
    log_success "Additional configuration files created"
}

# Validate environment file
validate_env_file() {
    log_info "Validating .env file..."
    
    if [ ! -f ".env" ]; then
        log_error ".env file not found!"
        log_info "Please create .env file with required variables"
        return 1
    fi
    
    # Check required variables
    local required_vars=(
        "OPENVAS_ADMIN_PWD"
        "VULNWHISPERER_ELASTIC"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" .env; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required variables in .env: ${missing_vars[*]}"
        return 1
    fi
    
    # Check for default passwords
    if grep -q "OPENVAS_ADMIN_PWD=ChangeMe!" .env; then
        log_warning "Default password detected for OpenVAS. Consider changing it."
    fi
    
    log_success ".env file validation passed"
}

# Display setup summary
display_summary() {
    log_success "Setup completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Review and customize configuration files in ./configs/"
    echo "2. Update scan targets in ./data/nmap-reports/targets.txt"
    echo "3. Customize environment variables in .env file"
    echo "4. Start the services: docker-compose up -d"
    echo "5. Check service health: ./modules/health-check.sh"
    echo
    log_info "Default services will be available at:"
    echo "- OpenVAS Web UI: http://localhost:9392"
    echo "- Admin username: admin"
    echo "- Admin password: (from OPENVAS_ADMIN_PWD in .env)"
    echo
    log_info "Data directories:"
    echo "- OpenVAS data: ./data/openvas/"
    echo "- Nmap reports: ./data/nmap-reports/"
    echo "- VulnWhisperer data: ./data/vulnwhisperer/"
    echo
    log_warning "Remember to:"
    echo "- Change default passwords"
    echo "- Configure firewall rules if needed"
    echo "- Set up log rotation for production use"
    echo "- Configure backup strategy for scan data"
}

# Main setup function
main() {
    echo "=== Vulnerability Scanning Environment Setup ==="
    echo
    
    check_root
    check_dependencies
    create_directories
    set_permissions
    generate_certificates
    create_additional_configs
    validate_env_file
    
    echo
    display_summary
}

# Run setup
main "$@"