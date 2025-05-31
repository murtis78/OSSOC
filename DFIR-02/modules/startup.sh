#!/bin/bash

# DFIR-02 Environment Startup Script
# This script initializes and starts the complete DFIR environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="dfir-02"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# Functions
print_header() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                        DFIR-02 Environment Setup                     ║"
    echo "║                   IRIS + Velociraptor Integration                     ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${YELLOW}🔄 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create directory structure
create_directories() {
    print_step "Creating directory structure..."
    
    directories=(
        "data/iris"
        "data/postgres"
        "data/redis"
        "data/velociraptor"
        "data/velociraptor-client"
        "configs/iris"
        "configs/postgres"
        "configs/velociraptor"
        "certs"
        "secrets"
        "modules"
        "logs"
        "backups"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        print_info "Created directory: $dir"
    done
    
    print_success "Directory structure created"
}

# Generate certificates
generate_certificates() {
    print_step "Generating SSL certificates..."
    
    if [ -f "./modules/generate-certs.sh" ]; then
        chmod +x "./modules/generate-certs.sh"
        ./modules/generate-certs.sh
        print_success "SSL certificates generated"
    else
        print_error "Certificate generation script not found"
        exit 1
    fi
}

# Install IRIS Velociraptor module
install_velociraptor_module() {
    print_step "Installing IRIS Velociraptor module..."
    
    if [ -f "./modules/install-iris-velociraptor-module.sh" ]; then
        chmod +x "./modules/install-iris-velociraptor-module.sh"
        ./modules/install-iris-velociraptor-module.sh
        print_success "IRIS Velociraptor module installed"
    else
        print_error "Velociraptor module installation script not found"
        exit 1
    fi
}

# Generate secrets
generate_secrets() {
    print_step "Generating secrets..."
    
    # Generate random passwords if not set
    if [ ! -f "./secrets/iris_admin_password" ]; then
        openssl rand -base64 32 > "./secrets/iris_admin_password"
        print_info "Generated IRIS admin password"
    fi
    
    if [ ! -f "./secrets/postgres_password" ]; then
        openssl rand -base64 32 > "./secrets/postgres_password"
        print_info "Generated PostgreSQL password"
    fi
    
    if [ ! -f "./secrets/redis_password" ]; then
        openssl rand -base64 32 > "./secrets/redis_password"
        print_info "Generated Redis password"
    fi
    
    if [ ! -f "./secrets/velociraptor_password" ]; then
        openssl rand -base64 32 > "./secrets/velociraptor_password"
        print_info "Generated Velociraptor password"
    fi
    
    # Set appropriate permissions
    chmod 600 ./secrets/*
    
    print_success "Secrets generated"
}

# Initialize Velociraptor configuration
init_velociraptor_config() {
    print_step "Initializing Velociraptor configuration..."
    
    # Generate Velociraptor configuration if it doesn't exist
    if [ ! -f "./configs/velociraptor/server.config.yaml" ]; then
        docker run --rm \
            -v "${PWD}/configs/velociraptor:/opt/velociraptor/config" \
            velociraptor/velociraptor:latest \
            config generate --config_path /opt/velociraptor/config/server.config.yaml
        
        print_info "Generated Velociraptor server configuration"
    fi
    
    print_success "Velociraptor configuration initialized"
}

# Start services
start_services() {
    print_step "Starting DFIR-02 services..."
    
    # Pull latest images
    docker-compose pull
    
    # Start services
    docker-compose up -d
    
    print_success "Services started"
}

# Wait for services to be ready
wait_for_services() {
    print_step "Waiting for services to be ready..."
    
    # Wait for database
    echo "Waiting for PostgreSQL..."
    until docker-compose exec -T iris-db pg_isready -U iris -d iris_db; do
        sleep 2
    done
    print_info "PostgreSQL is ready"
    
    # Wait for Redis
    echo "Waiting for Redis..."
    until docker-compose exec -T iris-redis redis-cli ping; do
        sleep 2
    done
    print_info "Redis is ready"
    
    # Wait for IRIS
    echo "Waiting for IRIS..."
    until curl -f http://localhost:8080/health &>/dev/null; do
        sleep 5
    done
    print_info "IRIS is ready"
    
    # Wait for Velociraptor
    echo "Waiting for Velociraptor..."
    until curl -f -k https://localhost:8889/app/index.html &>/dev/null; do
        sleep 5
    done
    print_info "Velociraptor is ready"
    
    print_success "All services are ready"
}

# Initialize database
init_db() {
    print_step "Checking if database initialization is needed..."
    # Lancer uniquement si le fichier existe et que la DB est up
    if [ -f "./configs/postgres/init.sql" ]; then
        # Attendre que le service postgres soit prêt
        until docker-compose exec -T iris-db pg_isready -U iris -d iris_db; do
            sleep 2
        done
        print_info "PostgreSQL is ready. Running initialization script..."
        # Exécuter le script SQL depuis le host dans le container
        docker cp ./configs/postgres/init.sql $(docker-compose ps -q iris-db):/tmp/init.sql
        docker-compose exec -T iris-db psql -U iris -d iris_db -f /tmp/init.sql || print_info "init.sql already executed or failed"
        print_success "Database initialization done"
    else
        print_info "No init.sql found, skipping DB initialization"
    fi
}

# Display access information
display_access_info() {
    print_header
    echo -e "${GREEN}🎉 DFIR-02 Environment is ready!${NC}"
    echo ""
    echo -e "${BLUE}Access Information:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${YELLOW}DFIR IRIS:${NC}"
    echo "  🌐 URL: http://localhost:8080"
    echo "  👤 Username: admin"
    echo "  🔑 Password: ChangeMe!"
    echo ""
    echo -e "${YELLOW}Velociraptor:${NC}"
    echo "  🌐 GUI URL: https://localhost:8889"
    echo "  🔌 API URL: https://localhost:8001"
    echo "  👤 Username: admin"
    echo "  🔑 Password: ChangeMe!"
    echo ""
    echo -e "${YELLOW}PostgreSQL:${NC}"
    echo "  🏠 Host: localhost:5432"
    echo "  🗄️  Database: iris_db"
    echo "  👤 Username: iris"
    echo "  🔑 Password: ChangeMe!"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  📊 View logs: docker-compose logs -f [service]"
    echo "  🔄 Restart: docker-compose restart [service]"
    echo "  🛑 Stop: docker-compose down"
    echo "  📋 Status: docker-compose ps"
    echo ""
    echo -e "${YELLOW}⚠️  Security Notes:${NC}"
    echo "  • Change default passwords in .env file"
    echo "  • Update SSL certificates for production use"
    echo "  • Configure firewall rules appropriately"
    echo "  • Review and update configuration files"
    echo ""
    echo -e "${GREEN}📚 Documentation:${NC}"
    echo "  • IRIS: https://docs.dfir-iris.org/"
    echo "  • Velociraptor: https://docs.velociraptor.app/"
    echo ""
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Setup failed. Cleaning up..."
        docker-compose down 2>/dev/null || true
    fi
}

# Main execution
main() {
    trap cleanup EXIT
    
    print_header
    
    # Check if already running
    if docker-compose ps | grep -q "Up"; then
        print_info "Services are already running. Use 'docker-compose down' to stop them first."
        exit 0
    fi
    
    # Execute setup steps
    check_prerequisites
    create_directories
    generate_certificates
    install_velociraptor_module
    generate_secrets
    init_velociraptor_config
    start_services
    wait_for_services
    init_db
    display_access_info
    
    print_success "DFIR-02 Environment setup completed successfully!"
}

# Handle command line arguments
case "${1:-start}" in
    start)
        main
        ;;
    stop)
        print_step "Stopping DFIR-02 services..."
        docker-compose down
        print_success "Services stopped"
        ;;
    restart)
        print_step "Restarting DFIR-02 services..."
        docker-compose down
        docker-compose up -d
        wait_for_services
        print_success "Services restarted"
        ;;
    status)
        docker-compose ps
        ;;
    logs)
        docker-compose logs -f "${2:-}"
        ;;
    update)
        print_step "Updating DFIR-02 services..."
        docker-compose pull
        docker-compose up -d
        print_success "Services updated"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        exit 1
        ;;
esac

exit 0