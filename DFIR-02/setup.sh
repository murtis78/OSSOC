#!/bin/bash

# DFIR-02 Stack Setup Script
# Automated deployment of IRIS + Velociraptor DFIR Stack
# Version: 1.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="dfir-02"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# Logging
LOG_FILE="setup.log"
exec 1> >(tee -a "${LOG_FILE}")
exec 2> >(tee -a "${LOG_FILE}" >&2)

# Print functions
print_header() {
    echo -e "${BLUE}"
    echo "=================================================================="
    echo "              DFIR-02 Stack - IRIS + Velociraptor"
    echo "=================================================================="
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Generate random secret key
generate_secret_key() {
    openssl rand -hex 32
}

# Check prerequisites
check_prerequisites() {
    print_step "Vérification des prérequis..."
    
    local missing_deps=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    # Check OpenSSL
    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Dépendances manquantes: ${missing_deps[*]}"
        print_error "Veuillez installer les dépendances manquantes et relancer le script."
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        print_error "Docker daemon n'est pas accessible. Vérifiez que Docker est démarré."
        exit 1
    fi
    
    print_success "Tous les prérequis sont satisfaits"
}

# Create directory structure
create_directories() {
    print_step "Création de la structure des répertoires..."
    
    local directories=(
        "configs/iris"
        "configs/postgres"
        "configs/velociraptor"
        "data/iris"
        "data/postgres"
        "data/redis"
        "data/velociraptor"
        "data/velociraptor-client"
        "certs"
        "secrets"
        "modules"
        "logs"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "${dir}"
        print_step "Créé: ${dir}/"
    done
    
    print_success "Structure des répertoires créée"
}

# Generate secrets
generate_secrets() {
    print_step "Génération des secrets et mots de passe..."
    
    # Generate passwords
    local postgres_password=$(generate_password)
    local redis_password=$(generate_password)
    local iris_admin_password=$(generate_password)
    local iris_secret_key=$(generate_secret_key)
    local velociraptor_password=$(generate_password)
    
    # Save secrets to files
    echo "${postgres_password}" > secrets/postgres_password
    echo "${redis_password}" > secrets/redis_password
    echo "${iris_admin_password}" > secrets/iris_admin_password
    echo "${iris_secret_key}" > secrets/iris_secret_key
    echo "${velociraptor_password}" > secrets/velociraptor_password
    
    # Set permissions
    chmod 600 secrets/*
    
    # Export to environment variables
    export POSTGRES_PASSWORD="${postgres_password}"
    export REDIS_PASSWORD="${redis_password}"
    export IRIS_ADMIN_PASSWORD="${iris_admin_password}"
    export IRIS_SECRET_KEY="${iris_secret_key}"
    export VELOCIRAPTOR_PASSWORD="${velociraptor_password}"
    
    print_success "Secrets générés et sauvegardés dans secrets/"
}

# Create .env file
create_env_file() {
    print_step "Création du fichier d'environnement (.env)..."
    
    # Load existing passwords if they exist
    local postgres_password="${POSTGRES_PASSWORD:-$(cat secrets/postgres_password 2>/dev/null || generate_password)}"
    local redis_password="${REDIS_PASSWORD:-$(cat secrets/redis_password 2>/dev/null || generate_password)}"
    local iris_admin_password="${IRIS_ADMIN_PASSWORD:-$(cat secrets/iris_admin_password 2>/dev/null || generate_password)}"
    local iris_secret_key="${IRIS_SECRET_KEY:-$(cat secrets/iris_secret_key 2>/dev/null || generate_secret_key)}"
    local velociraptor_password="${VELOCIRAPTOR_PASSWORD:-$(cat secrets/velociraptor_password 2>/dev/null || generate_password)}"
    
    cat > "${ENV_FILE}" << EOF
# DFIR-02 Stack Environment Configuration
# Generated on $(date)

# Network Configuration
NETWORK_SUBNET=172.20.0.0/16
TZ=Europe/Paris

# Ports Configuration
IRIS_PORT=8080
VELOCIRAPTOR_GUI_PORT=8889
VELOCIRAPTOR_API_PORT=8001
VELOCIRAPTOR_FRONTEND_PORT=8080

# PostgreSQL Configuration
POSTGRES_USER=iris
POSTGRES_PASSWORD=${postgres_password}
POSTGRES_DB=iris_db

# Redis Configuration
REDIS_PASSWORD=${redis_password}

# IRIS Configuration
IRIS_ADMIN_USER=admin
IRIS_ADMIN_PASSWORD=${iris_admin_password}
IRIS_ADMIN_EMAIL=admin@dfir.local
IRIS_SECRET_KEY=${iris_secret_key}
IRIS_HTTPS=false

# Velociraptor Configuration
VELOCIRAPTOR_USER=admin
VELOCIRAPTOR_PASSWORD=${velociraptor_password}

# SSL/TLS Configuration
CERT_COUNTRY=FR
CERT_STATE=IDF
CERT_CITY=Paris
CERT_ORG=DFIR-Lab
CERT_OU=Security
CERT_EMAIL=admin@dfir.local
EOF
    
    print_success "Fichier .env créé"
}

# Copy configuration files
copy_configs() {
    print_step "Copie des fichiers de configuration..."
    
    # Copy IRIS config
    if [ ! -f "configs/iris/config.toml" ]; then
        # Use the config from documents if available, otherwise create a basic one
        cat > "configs/iris/config.toml" << 'EOF'
# DFIR IRIS Configuration File

[app]
name = "DFIR IRIS"
version = "2.4.0"
debug = false
secret_key = "your-super-secret-key-change-me-please-use-long-random-string"

[server]
host = "0.0.0.0"
port = 8080
workers = 4
timeout = 30
max_content_length = 104857600  # 100MB

[database]
type = "postgresql"
host = "iris-db"
port = 5432
name = "iris_db"
user = "iris"
password = "ChangeMe!"
pool_size = 20
pool_timeout = 30
pool_recycle = 3600

[redis]
host = "iris-redis"
port = 6379
password = "ChangeMe!"
db = 0
socket_timeout = 5

[security]
password_policy = true
min_password_length = 8
require_uppercase = true
require_lowercase = true
require_numbers = true
require_special_chars = true
session_timeout = 3600
max_login_attempts = 5
lockout_duration = 900

[ssl]
enabled = false
cert_file = "/opt/iris/certs/iris.crt"
key_file = "/opt/iris/certs/iris.key"
ca_file = "/opt/iris/certs/ca.crt"

[logging]
level = "INFO"
format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
file = "/opt/iris/data/logs/iris.log"
max_bytes = 10485760  # 10MB
backup_count = 5

[modules]
enabled = true
path = "/opt/iris/modules"
auto_load = true

[integrations]
# Velociraptor Integration
[integrations.velociraptor]
enabled = true
server = "velociraptor-server"
port = 8080
api_port = 8001
username = "admin"
password = "ChangeMe!"
verify_ssl = false
timeout = 30
cert_file = "/opt/iris/certs/velociraptor-client.crt"
key_file = "/opt/iris/certs/velociraptor-client.key"
ca_file = "/opt/iris/certs/ca.crt"

[notifications]
enabled = true
email_backend = "smtp"
smtp_host = "localhost"
smtp_port = 587
smtp_user = ""
smtp_password = ""
smtp_tls = true

[uploads]
max_file_size = 104857600  # 100MB
allowed_extensions = [
    "txt", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
    "jpg", "jpeg", "png", "gif", "bmp", "svg",
    "zip", "rar", "7z", "tar", "gz",
    "pcap", "pcapng", "cap",
    "log", "csv", "json", "xml", "yaml", "yml"
]
upload_path = "/opt/iris/data/uploads"

[artifacts]
storage_path = "/opt/iris/data/artifacts"
max_storage_size = 10737418240  # 10GB

[cases]
default_classification = "TLP:AMBER"
auto_close_days = 90
evidence_retention_days = 365
EOF
        print_step "Configuration IRIS copiée"
    fi
    
    # Copy PostgreSQL init script
    cat > "configs/postgres/init.sql" << 'EOF'
-- PostgreSQL Initialization Script for DFIR IRIS

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Create schemas
CREATE SCHEMA IF NOT EXISTS iris;
CREATE SCHEMA IF NOT EXISTS velociraptor;

-- Set search path
ALTER DATABASE iris_db SET search_path TO iris, public;

-- Create iris user permissions
GRANT ALL PRIVILEGES ON SCHEMA iris TO iris;
GRANT ALL PRIVILEGES ON SCHEMA velociraptor TO iris;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA iris TO iris;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA iris TO iris;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA iris TO iris;

-- Create tables for Velociraptor integration
CREATE TABLE IF NOT EXISTS velociraptor.clients (
    client_id VARCHAR(255) PRIMARY KEY,
    hostname VARCHAR(255),
    os_info JSONB,
    first_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    labels TEXT[],
    status VARCHAR(50) DEFAULT 'online',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS velociraptor.hunts (
    hunt_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    creator VARCHAR(255),
    artifact_sources TEXT[],
    state VARCHAR(50) DEFAULT 'RUNNING',
    created_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires TIMESTAMP WITH TIME ZONE,
    client_count INTEGER DEFAULT 0,
    completed_clients INTEGER DEFAULT 0,
    stats JSONB
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_clients_hostname ON velociraptor.clients(hostname);
CREATE INDEX IF NOT EXISTS idx_clients_last_seen ON velociraptor.clients(last_seen);
CREATE INDEX IF NOT EXISTS idx_hunts_state ON velociraptor.hunts(state);
CREATE INDEX IF NOT EXISTS idx_hunts_created_time ON velociraptor.hunts(created_time);

-- Grant permissions on new tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA velociraptor TO iris;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA velociraptor TO iris;
EOF
    
    print_success "Fichiers de configuration copiés"
}

# Generate SSL certificates
generate_certificates() {
    print_step "Génération des certificats SSL..."
    
    # Load environment variables
    source "${ENV_FILE}" 2>/dev/null || true
    
    # Certificate settings
    local CERT_DIR="./certs"
    local CERT_COUNTRY="${CERT_COUNTRY:-FR}"
    local CERT_STATE="${CERT_STATE:-IDF}"
    local CERT_CITY="${CERT_CITY:-Paris}"
    local CERT_ORG="${CERT_ORG:-DFIR-Lab}"
    local CERT_OU="${CERT_OU:-Security}"
    local CERT_EMAIL="${CERT_EMAIL:-admin@dfir.local}"
    local CERT_VALIDITY=3650
    
    # Generate CA certificate
    print_step "Génération du certificat CA..."
    openssl genrsa -out "${CERT_DIR}/ca.key" 4096
    openssl req -new -x509 -days ${CERT_VALIDITY} -key "${CERT_DIR}/ca.key" -out "${CERT_DIR}/ca.crt" \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=DFIR-CA/emailAddress=${CERT_EMAIL}"
    
    # Generate IRIS certificate
    print_step "Génération du certificat IRIS..."
    openssl genrsa -out "${CERT_DIR}/iris.key" 4096
    openssl req -new -key "${CERT_DIR}/iris.key" -out "${CERT_DIR}/iris.csr" \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=iris-web/emailAddress=${CERT_EMAIL}"
    
    cat > "${CERT_DIR}/iris.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = DNS:iris-web,DNS:localhost,IP:127.0.0.1,IP:172.20.0.2
EOF
    
    openssl x509 -req -in "${CERT_DIR}/iris.csr" -CA "${CERT_DIR}/ca.crt" -CAkey "${CERT_DIR}/ca.key" \
        -CAcreateserial -out "${CERT_DIR}/iris.crt" -days ${CERT_VALIDITY} -extensions v3_req \
        -extfile "${CERT_DIR}/iris.ext"
    
    # Generate Velociraptor server certificate
    print_step "Génération du certificat Velociraptor..."
    openssl genrsa -out "${CERT_DIR}/velociraptor-server.key" 4096
    openssl req -new -key "${CERT_DIR}/velociraptor-server.key" -out "${CERT_DIR}/velociraptor-server.csr" \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=velociraptor-server/emailAddress=${CERT_EMAIL}"
    
    cat > "${CERT_DIR}/velociraptor-server.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = DNS:velociraptor-server,DNS:localhost,IP:127.0.0.1,IP:172.20.0.3
EOF
    
    openssl x509 -req -in "${CERT_DIR}/velociraptor-server.csr" -CA "${CERT_DIR}/ca.crt" -CAkey "${CERT_DIR}/ca.key" \
        -CAcreateserial -out "${CERT_DIR}/velociraptor-server.crt" -days ${CERT_VALIDITY} -extensions v3_req \
        -extfile "${CERT_DIR}/velociraptor-server.ext"
    
    # Clean up CSR and extension files
    rm -f "${CERT_DIR}"/*.csr "${CERT_DIR}"/*.ext
    
    # Set permissions
    find "${CERT_DIR}" -name "*.key" -exec chmod 600 {} \;
    find "${CERT_DIR}" -name "*.crt" -exec chmod 644 {} \;
    
    print_success "Certificats SSL générés"
}

# Install IRIS Velociraptor module
install_modules() {
    print_step "Installation du module IRIS-Velociraptor..."
    
    # Create basic module structure
    mkdir -p modules/iris-velociraptor/{hooks,config}
    
    # Create basic module files
    cat > modules/iris-velociraptor/__init__.py << 'EOF'
# IRIS Velociraptor Integration Module
__version__ = "1.0.0"
__author__ = "DFIR Team"
EOF
    
    cat > modules/iris-velociraptor/config.py << 'EOF'
# IRIS Velociraptor Module Configuration
VELOCIRAPTOR_CONFIG = {
    'server_url': 'https://velociraptor-server:8889',
    'api_url': 'https://velociraptor-server:8001',
    'username': 'admin',
    'verify_ssl': False,
    'timeout': 30
}
EOF
    
    print_success "Module IRIS-Velociraptor installé"
}

# Pull Docker images
pull_images() {
    print_step "Téléchargement des images Docker..."
    
    docker-compose pull
    
    print_success "Images Docker téléchargées"
}

# Start services
start_services() {
    print_step "Démarrage des services..."
    
    # Start services in order
    docker-compose up -d iris-db iris-redis
    
    print_step "Attente du démarrage de la base de données..."
    sleep 30
    
    docker-compose up -d iris-web velociraptor-server
    
    print_step "Attente du démarrage des services principaux..."
    sleep 60
    
    docker-compose up -d velociraptor-client
    
    print_success "Services démarrés"
}

# Check services health
check_services() {
    print_step "Vérification de l'état des services..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_step "Tentative $attempt/$max_attempts..."
        
        # Check IRIS
        if curl -f -s "http://localhost:${IRIS_PORT:-8080}/health" > /dev/null 2>&1; then
            print_success "IRIS est accessible"
            break
        fi
        
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_warning "IRIS pourrait ne pas être complètement démarré"
    fi
    
    # Check Velociraptor
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        print_step "Vérification Velociraptor - Tentative $attempt/$max_attempts..."
        
        if curl -f -s -k "https://localhost:${VELOCIRAPTOR_GUI_PORT:-8889}/app/index.html" > /dev/null 2>&1; then
            print_success "Velociraptor GUI est accessible"
            break
        fi
        
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_warning "Velociraptor GUI pourrait ne pas être complètement démarré"
    fi
}

# Display connection information
show_connection_info() {
    print_header
    print_success "Installation terminée avec succès!"
    echo ""
    echo -e "${BLUE}🌐 Informations de connexion:${NC}"
    echo ""
    echo -e "${GREEN}IRIS (Interface de gestion des incidents):${NC}"
    echo "  URL: http://localhost:${IRIS_PORT:-8080}"
    echo "  Utilisateur: ${IRIS_ADMIN_USER:-admin}"
    echo "  Mot de passe: $(cat secrets/iris_admin_password 2>/dev/null || echo 'Voir secrets/iris_admin_password')"
    echo ""
    echo -e "${GREEN}Velociraptor (Digital Forensics):${NC}"
    echo "  GUI: https://localhost:${VELOCIRAPTOR_GUI_PORT:-8889}"
    echo "  API: https://localhost:${VELOCIRAPTOR_API_PORT:-8001}"
    echo "  Utilisateur: ${VELOCIRAPTOR_USER:-admin}"
    echo "  Mot de passe: $(cat secrets/velociraptor_password 2>/dev/null || echo 'Voir secrets/velociraptor_password')"
    echo ""
    echo -e "${YELLOW}📁 Fichiers importants:${NC}"
    echo "  Configuration: configs/"
    echo "  Données: data/"
    echo "  Certificats: certs/"
    echo "  Secrets: secrets/"
    echo "  Logs: logs/"
    echo ""
    echo -e "${YELLOW}🔧 Commandes utiles:${NC}"
    echo "  Voir les logs: docker-compose logs -f"
    echo "  Arrêter: docker-compose down"
    echo "  Redémarrer: docker-compose restart"
    echo "  Statut: docker-compose ps"
    echo ""
    echo -e "${RED}⚠️  SÉCURITÉ:${NC}"
    echo "  - Changez les mots de passe par défaut en production"
    echo "  - Remplacez les certificats auto-signés par des certificats valides"
    echo "  - Configurez un pare-feu approprié"
    echo ""
}

# Cleanup function
cleanup() {
    print_step "Nettoyage en cas d'erreur..."
    docker-compose down 2>/dev/null || true
}

# Main function
main() {
    # Set trap for cleanup on error
    trap cleanup ERR
    
    print_header
    
    print_step "Début de l'installation de DFIR-02 Stack..."
    
    # Check if we're in the right directory
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml non trouvé. Exécutez ce script depuis le répertoire dfir-02."
        exit 1
    fi
    
    # Main installation steps
    check_prerequisites
    create_directories
    generate_secrets
    create_env_file
    copy_configs
    generate_certificates
    install_modules
    pull_images
    start_services
    check_services
    show_connection_info
    
    print_success "Installation DFIR-02 Stack terminée!"
}

# Handle command line arguments
case "${1:-}" in
    "start")
        print_step "Démarrage des services..."
        docker-compose up -d
        check_services
        show_connection_info
        ;;
    "stop")
        print_step "Arrêt des services..."
        docker-compose down
        print_success "Services arrêtés"
        ;;
    "restart")
        print_step "Redémarrage des services..."
        docker-compose restart
        check_services
        show_connection_info
        ;;
    "status")
        print_step "Statut des services:"
        docker-compose ps
        ;;
    "logs")
        docker-compose logs -f
        ;;
    "update")
        print_step "Mise à jour des images..."
        docker-compose pull
        docker-compose up -d
        print_success "Images mises à jour"
        ;;
    "clean")
        print_warning "Suppression de tous les containers et volumes..."
        read -p "Êtes-vous sûr? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker-compose down -v
            docker system prune -f
            print_success "Nettoyage terminé"
        fi
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  (none)    Installation complète"
        echo "  start     Démarrer les services"
        echo "  stop      Arrêter les services"
        echo "  restart   Redémarrer les services"
        echo "  status    Voir le statut des services"
        echo "  logs      Voir les logs en temps réel"
        echo "  update    Mettre à jour les images"
        echo "  clean     Nettoyer complètement (DESTRUCTIF)"
        echo "  help      Afficher cette aide"
        ;;
    "")
        main
        ;;
    *)
        print_error "Commande inconnue: $1"
        echo "Utilisez '$0 help' pour voir les commandes disponibles."
        exit 1
        ;;
esac
