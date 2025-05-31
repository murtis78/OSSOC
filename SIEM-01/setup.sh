#!/bin/bash

# Script de setup pour la stack SIEM Elastic
# Usage: ./setup.sh

set -e

echo "🚀 Configuration de la stack SIEM Elastic..."

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification des prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    # Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    # Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose n'est pas installé"
        exit 1
    fi
    
    # Vérification de la mémoire virtuelle
    current_vm_max_map_count=$(sysctl vm.max_map_count | cut -d' ' -f3)
    if [ "$current_vm_max_map_count" -lt 262144 ]; then
        log_warning "vm.max_map_count est trop bas ($current_vm_max_map_count). Recommandé: 262144"
        log_info "Exécutez: sudo sysctl -w vm.max_map_count=262144"
        log_info "Pour rendre permanent: echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf"
    fi
    
    log_success "Prérequis vérifiés"
}

# Création de la structure des dossiers
create_directories() {
    log_info "Création de la structure des dossiers..."
    
    # Dossiers principaux
    mkdir -p {data/esdata,data/logstash-data,certs,secrets,modules}
    mkdir -p {configs/elasticsearch,configs/logstash,configs/kibana}
    
    # Permissions
    chmod 750 certs secrets
    chmod 755 data/esdata data/logstash-data modules
    
    # Pour Elasticsearch (UID 1000)
    sudo chown -R 1000:1000 data/esdata
    sudo chown -R 1000:1000 certs
    
    log_success "Structure des dossiers créée"
}

# Génération des mots de passe sécurisés
generate_passwords() {
    log_info "Génération des mots de passe..."
    
    if [ ! -f .env ]; then
        log_error "Fichier .env non trouvé. Veuillez le créer d'abord."
        exit 1
    fi
    
    # Génération de clés de chiffrement Kibana si nécessaires
    if ! grep -q "KIBANA_ENCRYPTION_KEY=" .env; then
        KIBANA_KEY=$(openssl rand -hex 32)
        echo "KIBANA_ENCRYPTION_KEY=$KIBANA_KEY" >> .env
        log_success "Clé de chiffrement Kibana générée"
    fi
    
    log_warning "Pensez à changer les mots de passe par défaut dans le fichier .env !"
}

# Démarrage de la stack
start_stack() {
    log_info "Démarrage de la stack..."
    
    # Setup des certificats
    log_info "Configuration des certificats SSL..."
    docker-compose up setup
    
    # Démarrage des services
    log_info "Démarrage des services..."
    docker-compose up -d elasticsearch
    
    # Attendre qu'Elasticsearch soit prêt
    log_info "Attente du démarrage d'Elasticsearch..."
    while ! curl -s -k https://localhost:9200 | grep -q "missing authentication credentials"; do
        echo -n "."
        sleep 5
    done
    echo ""
    log_success "Elasticsearch démarré"
    
    # Configuration des utilisateurs
    log_info "Configuration des utilisateurs système..."
    docker-compose exec elasticsearch bin/elasticsearch-setup-passwords auto --batch --url https://localhost:9200
    
    # Démarrage des autres services
    log_info "Démarrage de Logstash et Kibana..."
    docker-compose up -d logstash kibana
    
    # Attendre que Kibana soit prêt
    log_info "Attente du démarrage de Kibana..."
    while ! curl -s http://localhost:5601 | grep -q "Kibana server is not ready yet"; do
        echo -n "."
        sleep 10
    done
    echo ""
    log_success "Kibana démarré"
}

# Configuration post-déploiement
post_setup() {
    log_info "Configuration post-déploiement..."
    
    # Import des dashboards SIEM
    log_info "Import des templates et dashboards..."
    
    # Templates d'index pour les logs SIEM
    curl -X PUT "https://localhost:9200/_index_template/siem-logs" \
        -H "Content-Type: application/json" \
        -u "elastic:${ELASTIC_PASSWORD}" \
        --cacert certs/ca/ca.crt \
        -d '{
            "index_patterns": ["wazuh-*", "winlogbeat-*", "filebeat-*", "suricata-*"],
            "priority": 200,
            "template": {
                "settings": {
                    "number_of_shards": 1,
                    "number_of_replicas": 0,
                    "index.refresh_interval": "5s",
                    "index.max_result_window": 50000
                },
                "mappings": {
                    "properties": {
                        "@timestamp": {"type": "date"},
                        "agent": {
                            "properties": {
                                "hostname": {"type": "keyword"},
                                "type": {"type": "keyword"},
                                "version": {"type": "keyword"}
                            }
                        },
                        "geoip": {
                            "properties": {
                                "location": {"type": "geo_point"}
                            }
                        },
                        "event": {
                            "properties": {
                                "action": {"type": "keyword"},
                                "category": {"type": "keyword"},
                                "dataset": {"type": "keyword"},
                                "kind": {"type": "keyword"},
                                "module": {"type": "keyword"},
                                "outcome": {"type": "keyword"},
                                "severity": {"type": "integer"},
                                "type": {"type": "keyword"}
                            }
                        }
                    }
                }
            }
        }'
    
    log_success "Templates d'index configurés"
}

# Affichage des informations de connexion
display_info() {
    log_success "🎉 Installation terminée !"
    echo ""
    echo "📋 Informations de connexion:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 Kibana: http://localhost:5601"
    echo "🔍 Elasticsearch: https://localhost:9200"
    echo "⚡ Logstash: http://localhost:9600"
    echo ""
    echo "👤 Utilisateur par défaut:"
    echo "   Username: elastic"
    echo "   Password: ${ELASTIC_PASSWORD} (configuré dans .env)"
    echo ""
    echo "📊 Services SIEM disponibles:"
    echo "   • Security Solution (SIEM)"
    echo "   • Fleet Management"
    echo "   • Endpoint Security"
    echo "   • UEBA (User Entity Behavior Analytics)"
    echo "   • Detection Rules"
    echo "   • Case Management"
    echo ""
    echo "🔌 Ports d'écoute pour les agents:"
    echo "   • Beats: 5044"
    echo "   • Wazuh: 5045"
    echo "   • Syslog: 5514"
    echo "   • JSON HTTP: 8080"
    echo ""
    echo "⚠️  Notes importantes:"
    echo "   1. Changez les mots de passe par défaut dans .env"
    echo "   2. Configurez vm.max_map_count=262144 pour la production"
    echo "   3. Vérifiez les certificats SSL dans ./certs/"
    echo "   4. Les données sont persistées dans ./data/"
    echo ""
    echo "📚 Prochaines étapes:"
    echo "   1. Accédez à Kibana: http://localhost:5601"
    echo "   2. Configurez Fleet Server"
    echo "   3. Déployez des agents Elastic"
    echo "   4. Importez des règles de détection"
    echo "   5. Configurez les alertes"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Vérification de l'état des services
check_services() {
    log_info "Vérification de l'état des services..."
    
    services=("elasticsearch" "logstash" "kibana")
    for service in "${services[@]}"; do
        if docker-compose ps $service | grep -q "Up"; then
            log_success "$service: ✅ En cours d'exécution"
        else
            log_error "$service: ❌ Arrêté"
        fi
    done
}

# Menu principal
main_menu() {
    echo "🛡️  Configuration SIEM Elastic Stack"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Installation complète"
    echo "2. Vérifier les prérequis"
    echo "3. Créer la structure des dossiers"
    echo "4. Démarrer la stack"
    echo "5. Vérifier l'état des services"
    echo "6. Arrêter la stack"
    echo "7. Nettoyer (ATTENTION: supprime toutes les données)"
    echo "8. Afficher les logs"
    echo "9. Quitter"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    read -p "Choisissez une option [1-9]: " choice
    
    case $choice in
        1)
            log_info "🚀 Installation complète..."
            check_prerequisites
            create_directories
            generate_passwords
            start_stack
            post_setup
            display_info
            ;;
        2)
            check_prerequisites
            ;;
        3)
            create_directories
            ;;
        4)
            start_stack
            ;;
        5)
            check_services
            ;;
        6)
            log_info "Arrêt de la stack..."
            docker-compose down
            log_success "Stack arrêtée"
            ;;
        7)
            log_warning "⚠️  ATTENTION: Cette action supprimera toutes les données !"
            read -p "Êtes-vous sûr ? (oui/non): " confirm
            if [ "$confirm" = "oui" ]; then
                log_info "Nettoyage en cours..."
                docker-compose down -v
                sudo rm -rf data/ certs/ secrets/
                docker system prune -f
                log_success "Nettoyage terminé"
            else
                log_info "Nettoyage annulé"
            fi
            ;;
        8)
            echo "Choisissez le service:"
            echo "1. Elasticsearch"
            echo "2. Logstash" 
            echo "3. Kibana"
            read -p "Service [1-3]: " service_choice
            case $service_choice in
                1) docker-compose logs -f elasticsearch ;;
                2) docker-compose logs -f logstash ;;
                3) docker-compose logs -f kibana ;;
                *) log_error "Choix invalide" ;;
            esac
            ;;
        9)
            log_info "Au revoir !"
            exit 0
            ;;
        *)
            log_error "Choix invalide"
            main_menu
            ;;
    esac
}

# Point d'entrée principal
if [ "$1" = "--auto" ]; then
    # Mode automatique
    check_prerequisites
    create_directories
    generate_passwords
    start_stack
    post_setup
    display_info
else
    # Mode interactif
    main_menu
fi