#!/bin/bash

# Script de configuration et démarrage de la stack SIEM
set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Configuration de la stack SIEM${NC}"

# Vérification des prérequis
check_requirements() {
    echo -e "${YELLOW}Vérification des prérequis...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker n'est pas installé${NC}"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose n'est pas installé${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prérequis OK${NC}"
}

# Création de la structure de dossiers
create_directories() {
    echo -e "${YELLOW}Création de la structure de dossiers...${NC}"
    
    mkdir -p {data/{wazuh-indexer,opensearch,graylog,mongo,wazuh},configs/{wazuh,opensearch,graylog},certs,secrets,modules/{dashboards,templates,content-packs}}
    
    # Permissions pour les données
    sudo chown -R 1000:1000 data/opensearch
    sudo chown -R 1000:1000 data/wazuh-indexer
    sudo chmod 777 data/graylog
    
    echo -e "${GREEN}✅ Structure créée${NC}"
}

# Génération des certificats TLS
generate_certificates() {
    echo -e "${YELLOW}Génération des certificats TLS...${NC}"
    
    if [ ! -f "certs/root-ca.pem" ]; then
        cd certs
        
        # CA Root
        openssl genrsa -out root-ca-key.pem 2048
        openssl req -new -x509 -sha256 -key root-ca-key.pem -out root-ca.pem -days 365 \
            -subj "/C=FR/ST=IDF/L=Paris/O=SIEM/OU=IT/CN=root-ca"
        
        # Certificat OpenSearch
        openssl genrsa -out opensearch-key.pem 2048
        openssl req -new -key opensearch-key.pem -out opensearch.csr \
            -subj "/C=FR/ST=IDF/L=Paris/O=SIEM/OU=IT/CN=opensearch"
        openssl x509 -req -in opensearch.csr -CA root-ca.pem -CAkey root-ca-key.pem \
            -CAcreateserial -sha256 -out opensearch.pem -days 365
        
        # Certificat Wazuh Indexer
        openssl genrsa -out wazuh-indexer-key.pem 2048
        openssl req -new -key wazuh-indexer-key.pem -out wazuh-indexer.csr \
            -subj "/C=FR/ST=IDF/L=Paris/O=SIEM/OU=IT/CN=wazuh-indexer"
        openssl x509 -req -in wazuh-indexer.csr -CA root-ca.pem -CAkey root-ca-key.pem \
            -CAcreateserial -sha256 -out wazuh-indexer.pem -days 365
        
        # Certificat Filebeat
        openssl genrsa -out filebeat-key.pem 2048
        openssl req -new -key filebeat-key.pem -out filebeat.csr \
            -subj "/C=FR/ST=IDF/L=Paris/O=SIEM/OU=IT/CN=filebeat"
        openssl x509 -req -in filebeat.csr -CA root-ca.pem -CAkey root-ca-key.pem \
            -CAcreateserial -sha256 -out filebeat.pem -days 365
        
        # Certificat Dashboard  
        openssl genrsa -out wazuh-dashboard-key.pem 2048
        openssl req -new -key wazuh-dashboard-key.pem -out wazuh-dashboard.csr \
            -subj "/C=FR/ST=IDF/L=Paris/O=SIEM/OU=IT/CN=wazuh-dashboard"
        openssl x509 -req -in wazuh-dashboard.csr -CA root-ca.pem -CAkey root-ca-key.pem \
            -CAcreateserial -sha256 -out wazuh-dashboard.pem -days 365
        
        # Nettoyage
        rm *.csr
        
        cd ..
        echo -e "${GREEN}✅ Certificats générés${NC}"
    else
        echo -e "${GREEN}✅ Certificats déjà présents${NC}"
    fi
}

# Configuration des paramètres système
configure_system() {
    echo -e "${YELLOW}Configuration des paramètres système...${NC}"
    
    # Augmentation des limites de mémoire virtuelle pour OpenSearch
    echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -w vm.max_map_count=262144
    
    # Configuration des ulimits
    echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf
    echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf
    
    echo -e "${GREEN}✅ Système configuré${NC}"
}

# Génération du hash pour Graylog
generate_graylog_hash() {
    if [ ! -f ".env" ]; then
        echo -e "${RED}❌ Fichier .env manquant${NC}"
        exit 1
    fi
    
    PASSWORD=$(grep GRAYLOG_ADMIN_PWD .env | cut -d'=' -f2)
    HASH=$(echo -n "$PASSWORD" | sha256sum | cut -d' ' -f1)
    
    # Mise à jour du fichier .env avec le hash généré
    sed -i "s/GRAYLOG_ROOT_PASSWORD_SHA2=.*/GRAYLOG_ROOT_PASSWORD_SHA2=$HASH/" .env
    
    echo -e "${GREEN}✅ Hash Graylog généré${NC}"
}

# Création des templates de modules
create_templates() {
    echo -e "${YELLOW}Création des templates...${NC}"
    
    # Template Wazuh Dashboard
    cat > modules/dashboards/wazuh-security-dashboard.json << 'EOF'
{
  "version": "4.7.4",
  "objects": [
    {
      "id": "wazuh-security-overview",
      "type": "dashboard",
      "attributes": {
        "title": "Wazuh Security Overview",
        "description": "Vue d'ensemble de la sécurité Wazuh",
        "panelsJSON": "[]",
        "timeRestore": false,
        "version": 1
      }
    }
  ]
}
EOF

    # Template Graylog Content Pack
    cat > modules/content-packs/wazuh-integration.json << 'EOF'
{
  "v": "1",
  "id": "wazuh-integration-pack",
  "rev": 1,
  "name": "Wazuh Integration Pack",
  "summary": "Pack d'intégration Wazuh pour Graylog",
  "description": "Contient les extractors et dashboards pour l'intégration Wazuh",
  "vendor": "SIEM Stack",
  "url": "",
  "parameters": [],
  "entities": []
}
EOF

    echo -e "${GREEN}✅ Templates créés${NC}"
}

# Démarrage des services
start_services() {
    echo -e "${YELLOW}Démarrage des services...${NC}"
    
    # Démarrage de MongoDB et OpenSearch en premier
    docker-compose up -d mongodb opensearch
    echo -e "${BLUE}⏳ Attente de MongoDB et OpenSearch...${NC}"
    sleep 30
    
    # Démarrage de Wazuh Indexer
    docker-compose up -d wazuh-indexer
    echo -e "${BLUE}⏳ Attente de Wazuh Indexer...${NC}"
    sleep 20
    
    # Démarrage de Wazuh Manager
    docker-compose up -d wazuh-manager
    echo -e "${BLUE}⏳ Attente de Wazuh Manager...${NC}"
    sleep 15
    
    # Démarrage de Graylog et Wazuh Dashboard
    docker-compose up -d graylog wazuh-dashboard
    
    echo -e "${GREEN}✅ Services démarrés${NC}"
}

# Vérification des services
check_services() {
    echo -e "${YELLOW}Vérification des services...${NC}"
    
    services=("mongodb" "opensearch" "wazuh-indexer" "wazuh-manager" "graylog" "wazuh-dashboard")
    
    for service in "${services[@]}"; do
        if docker-compose ps $service | grep -q "Up"; then
            echo -e "${GREEN}✅ $service: OK${NC}"
        else
            echo -e "${RED}❌ $service: KO${NC}"
        fi
    done
}

# Affichage des informations de connexion
show_info() {
    echo -e "\n${BLUE}🎉 Stack SIEM déployée avec succès !${NC}\n"
    
    echo -e "${YELLOW}📋 Informations de connexion:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo -e "${GREEN}🔍 Wazuh Dashboard:${NC}"
    echo -e "   URL: https://localhost:443"
    echo -e "   Utilisateur: admin"
    echo -e "   Mot de passe: ChangeMe!"
    echo ""
    
    echo -e "${GREEN}📊 Graylog:${NC}"
    echo -e "   URL: http://localhost:9000"
    echo -e "   Utilisateur: admin"
    echo -e "   Mot de passe: ChangeMe!"
    echo ""
    
    echo -e "${GREEN}🔎 OpenSearch:${NC}"
    echo -e "   URL: https://localhost:9200"
    echo -e "   Utilisateur: admin"
    echo -e "   Mot de passe: ChangeMe!"
    echo ""
    
    echo -e "${GREEN}📈 Wazuh API:${NC}"
    echo -e "   URL: https://localhost:55000"
    echo -e "   Utilisateur: admin"
    echo -e "   Mot de passe: ChangeMe!"
    echo ""
    
    echo -e "${YELLOW}📝 Commandes utiles:${NC}"
    echo -e "   Logs: docker-compose logs -f [service]"
    echo -e "   Restart: docker-compose restart [service]"
    echo -e "   Stop: docker-compose down"
    echo -e "   Status: docker-compose ps"
    echo ""
    
    echo -e "${RED}⚠️  N'oubliez pas de changer les mots de passe par défaut !${NC}"
}

# Fonction principale
main() {
    check_requirements
    create_directories
    generate_certificates
    configure_system
    generate_graylog_hash
    create_templates
    start_services
    sleep 30
    check_services
    show_info
}

# Gestion des arguments
case "${1:-}" in
    "certificates")
        generate_certificates
        ;;
    "start")
        start_services
        ;;
    "stop")
        docker-compose down
        ;;
    "status")
        check_services
        ;;
    "logs")
        docker-compose logs -f "${2:-}"
        ;;
    "clean")
        docker-compose down -v
        sudo rm -rf data/*
        ;;
    *)
        main
        ;;
esac