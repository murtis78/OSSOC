#!/bin/bash

# Script d'installation automatique pour NGiNX Proxy Manager
# Auteur: Configuration Docker
# Version: 1.0

set -e  # Arrêter le script en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage
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

# Configuration par défaut
PROJECT_DIR="rp-01"
ADMIN_EMAIL="admin@example.com"
ADMIN_PASSWORD="ChangeMe123!"
COUNTRY="FR"
STATE="Ile-de-France"
CITY="Paris"
ORGANIZATION="MyOrganization"

# Fonction d'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --dir DIR          Répertoire du projet (défaut: rp-01)"
    echo "  -e, --email EMAIL      Email administrateur"
    echo "  -p, --password PASS    Mot de passe administrateur"
    echo "  --country COUNTRY      Pays pour les certificats SSL (défaut: FR)"
    echo "  --state STATE          État/Région pour les certificats SSL"
    echo "  --city CITY            Ville pour les certificats SSL"
    echo "  --org ORG              Organisation pour les certificats SSL"
    echo "  -h, --help             Afficher cette aide"
    echo ""
    echo "Exemple:"
    echo "  $0 -d mon-proxy -e admin@mondomaine.com -p MonMotDePasse123"
}

# Traitement des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        -e|--email)
            ADMIN_EMAIL="$2"
            shift 2
            ;;
        -p|--password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --country)
            COUNTRY="$2"
            shift 2
            ;;
        --state)
            STATE="$2"
            shift 2
            ;;
        --city)
            CITY="$2"
            shift 2
            ;;
        --org)
            ORGANIZATION="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Vérification des dépendances
check_dependencies() {
    print_status "Vérification des dépendances..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker n'est pas installé. Veuillez l'installer d'abord."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose n'est pas installé. Veuillez l'installer d'abord."
        exit 1
    fi
    
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL n'est pas installé. Veuillez l'installer d'abord."
        exit 1
    fi
    
    print_success "Toutes les dépendances sont installées."
}

# Création de la structure des dossiers
create_directory_structure() {
    print_status "Création de la structure des dossiers dans $PROJECT_DIR..."
    
    mkdir -p "$PROJECT_DIR"/{configs/nginx-proxy-manager,data,certs,secrets/ssl,modules,backups}
    
    print_success "Structure des dossiers créée."
}

# Génération du fichier .env
generate_env_file() {
    print_status "Génération du fichier .env..."
    
    cat > "$PROJECT_DIR/.env" << EOF
# Configuration NGiNX Proxy Manager
# Base de données SQLite
DB_SQLITE_FILE=/data/database.sqlite

# Configuration réseau
DISABLE_IPV6=true

# Configuration initiale (utilisé au premier démarrage uniquement)
NPM_INIT_EMAIL=$ADMIN_EMAIL
NPM_INIT_PWD=$ADMIN_PASSWORD

# Configuration SSL/TLS
SSL_CERT_PATH=/secrets/ssl
OPENSSL_COUNTRY=$COUNTRY
OPENSSL_STATE=$STATE
OPENSSL_CITY=$CITY
OPENSSL_ORG=$ORGANIZATION
OPENSSL_UNIT=IT Department

# Configuration Let's Encrypt
LETSENCRYPT_EMAIL=$ADMIN_EMAIL
LETSENCRYPT_STAGING=false

# Configuration de sécurité
NPM_SECRET_KEY=$(openssl rand -hex 32)
ADMIN_SESSION_TIMEOUT=3600

# Configuration du serveur
NPM_LISTEN_HTTP=80
NPM_LISTEN_HTTPS=443
NPM_LISTEN_ADMIN=81

# Logs et monitoring
LOG_LEVEL=info
ACCESS_LOG_FORMAT=combined

# Backup et maintenance
BACKUP_ENABLED=true
BACKUP_RETENTION_DAYS=30
EOF
    
    print_success "Fichier .env généré."
}

# Génération des certificats SSL par défaut
generate_ssl_certificates() {
    print_status "Génération des certificats SSL par défaut..."
    
    # Certificat par défaut
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$PROJECT_DIR/secrets/ssl/default.key" \
        -out "$PROJECT_DIR/secrets/ssl/default.crt" \
        -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=IT Department/CN=localhost" \
        2>/dev/null
    
    # Certificat wildcard pour développement
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$PROJECT_DIR/secrets/ssl/wildcard.key" \
        -out "$PROJECT_DIR/secrets/ssl/wildcard.crt" \
        -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=IT Department/CN=*.local.dev" \
        2>/dev/null
    
    # Définir les permissions
    chmod 600 "$PROJECT_DIR/secrets/ssl/"*.key
    chmod 644 "$PROJECT_DIR/secrets/ssl/"*.crt
    
    print_success "Certificats SSL générés."
}

# Génération des scripts utiles
generate_utility_scripts() {
    print_status "Génération des scripts utiles..."
    
    # Script de backup
    cat > "$PROJECT_DIR/backup.sh" << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
echo "Création du backup npm_backup_$DATE.tar.gz..."
tar -czf backups/npm_backup_$DATE.tar.gz data/ certs/ secrets/
echo "Suppression des anciens backups (>30 jours)..."
find backups/ -name "npm_backup_*.tar.gz" -mtime +30 -delete
echo "Backup terminé."
EOF
    
    # Script de monitoring SSL
    cat > "$PROJECT_DIR/check-ssl.sh" << 'EOF'
#!/bin/bash
echo "=== Vérification des certificats SSL ==="
for cert in secrets/ssl/*.crt; do
    if [ -f "$cert" ]; then
        echo "=== $(basename $cert) ==="
        openssl x509 -in "$cert" -noout -subject -dates
        echo
    fi
done
EOF
    
    # Script de démarrage
    cat > "$PROJECT_DIR/start.sh" << 'EOF'
#!/bin/bash
echo "Démarrage de NGiNX Proxy Manager..."
docker-compose up -d
echo "En attente du démarrage des services..."
sleep 10
echo "Vérification de l'état des services..."
docker-compose ps
echo ""
echo "Interface d'administration disponible sur :"
echo "http://$(hostname -I | awk '{print $1}'):81"
echo ""
echo "Identifiants par défaut :"
echo "Email: $(grep NPM_INIT_EMAIL .env | cut -d'=' -f2)"
echo "Mot de passe: $(grep NPM_INIT_PWD .env | cut -d'=' -f2)"
echo ""
echo "⚠️  N'oubliez pas de changer ces identifiants après la première connexion !"
EOF
    
    # Rendre les scripts exécutables
    chmod +x "$PROJECT_DIR"/{backup.sh,check-ssl.sh,start.sh}
    
    print_success "Scripts utiles générés."
}

# Vérification des ports
check_ports() {
    print_status "Vérification de la disponibilité des ports..."
    
    for port in 80 443 81; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_warning "Le port $port est déjà utilisé. Vous devrez peut-être arrêter d'autres services."
        fi
    done
}

# Affichage des informations finales
show_final_info() {
    print_success "Installation terminée avec succès !"
    echo ""
    echo "Prochaines étapes :"
    echo "1. cd $PROJECT_DIR"
    echo "2. ./start.sh  (ou docker-compose up -d)"
    echo "3. Accéder à l'interface : http://$(hostname -I | awk '{print $1}'):81"
    echo ""
    echo "Identifiants initiaux :"
    echo "  Email: $ADMIN_EMAIL"
    echo "  Mot de passe: $ADMIN_PASSWORD"
    echo ""
    echo "⚠️  Important :"
    echo "- Changez immédiatement les identifiants par défaut"
    echo "- Vérifiez que les ports 80, 443 et 81 sont accessibles"
    echo "- Configurez votre DNS pour pointer vers ce serveur"
    echo ""
    echo "Scripts disponibles :"
    echo "  ./start.sh       - Démarrer les services"
    echo "  ./backup.sh      - Créer une sauvegarde"
    echo "  ./check-ssl.sh   - Vérifier les certificats SSL"
    echo ""
    echo "Documentation complète dans README.md"
}

# Main function
main() {
    echo "========================================"
    echo "  NGiNX Proxy Manager - Installation   "
    echo "========================================"
    echo ""
    
    print_status "Début de l'installation..."
    print_status "Répertoire du projet: $PROJECT_DIR"
    print_status "Email administrateur: $ADMIN_EMAIL"
    echo ""
    
    check_dependencies
    create_directory_structure
    generate_env_file
    generate_ssl_certificates
    generate_utility_scripts
    check_ports
    
    echo ""
    show_final_info
}

# Exécution du script principal
main "$@"
