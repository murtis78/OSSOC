#!/bin/bash

# setup.sh - Déploiement automatisé de la plateforme DFIR-02 (IRIS + Velociraptor)
# Usage: ./setup.sh [--no-cert] [--skip-docker]

# ------------------------------------------------------------------------------
# Configuration Initiale
# ------------------------------------------------------------------------------

# Variables critiques
CONFIG_DIR="./configs"
CERTS_DIR="./certs"
SECRETS_DIR="./secrets"
MODULES_DIR="./modules"
ENV_FILE=".env"

# Couleurs pour la sortie terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# Fonctions Utilitaires
# ------------------------------------------------------------------------------

error_exit() {
  echo -e "${RED}[ERREUR] $1${NC}" >&2
  exit 1
}

check_dependency() {
  if ! command -v $1 &> /dev/null; then
    error_exit "Dépendance manquante: $1. Veuillez l'installer avant de continuer."
  fi
}

generate_password() {
  tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | head -c 24
}

# ------------------------------------------------------------------------------
# Vérification des Prérequis
# ------------------------------------------------------------------------------

echo -e "${YELLOW}>>> Vérification des prérequis système...${NC}"

# Vérifier les dépendances
check_dependency docker
check_dependency docker-compose
check_dependency openssl

# Vérifier les permissions Docker
if ! docker info > /dev/null 2>&1; then
  error_exit "Docker ne semble pas en cours d'exécution ou vous n'avez pas les permissions nécessaires."
fi

# ------------------------------------------------------------------------------
# Initialisation de l'Environnement
# ------------------------------------------------------------------------------

echo -e "${YELLOW}>>> Configuration de l'environnement...${NC}"

# Créer l'arborescence des dossiers
mkdir -p {$CONFIG_DIR,$CERTS_DIR,$SECRETS_DIR,$MODULES_DIR}/{iris,velociraptor,postgres}

# Initialiser le fichier .env s'il n'existe pas
if [ ! -f "$ENV_FILE" ]; then
  cat << EOF > "$ENV_FILE"
# Configuration DFIR-02
SERVER_IP=10.0.30.3
SUBNET=10.0.30.0/24
GATEWAY=10.0.30.1

# Mots de passe
POSTGRES_PASSWORD=$(generate_password)
IRIS_SECRET_KEY=$(generate_password)
VELOCIRAPTOR_HASH_SECRET=$(generate_password)

# Paramètres spécifiques
IRIS_URL=http://$SERVER_IP:8000
VELOCIRAPTOR_SERVER_URL=https://$SERVER_IP:8889
EOF
  echo -e "${GREEN}Fichier .env créé avec des valeurs par défaut.${NC}"
else
  echo -e "${GREEN}Fichier .env existant détecté.${NC}"
fi

# Charger les variables d'environnement
source "$ENV_FILE"

# ------------------------------------------------------------------------------
# Génération des Certificats
# ------------------------------------------------------------------------------

if [[ $1 != "--no-cert" ]]; then
  echo -e "${YELLOW}>>> Génération des certificats TLS...${NC}"
  
  # Vérifier si le module de génération existe
  if [ -f "$MODULES_DIR/generate-certs.sh" ]; then
    bash "$MODULES_DIR/generate-certs.sh" "$SERVER_IP"
  else
    # Fallback si le script est manquant
    openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
      -keyout "$CERTS_DIR/server.key" \
      -out "$CERTS_DIR/server.crt" \
      -subj "/CN=$SERVER_IP" \
      -addext "subjectAltName=IP:$SERVER_IP"
    
    cp "$CERTS_DIR/server.key" "$CERTS_DIR/client.key"
    cp "$CERTS_DIR/server.crt" "$CERTS_DIR/client.crt"
  fi

  # Sécuriser les permissions
  chmod 600 "$CERTS_DIR"/*.key
fi

# ------------------------------------------------------------------------------
# Configuration des Services
# ------------------------------------------------------------------------------

echo -e "${YELLOW}>>> Configuration des fichiers de service...${NC}"

# Configuration IRIS
if [ ! -f "$CONFIG_DIR/iris/config.toml" ]; then
  cat << EOF > "$CONFIG_DIR/iris/config.toml"
[system]
host = "0.0.0.0"
port = 8000
secret_key = "$IRIS_SECRET_KEY"

[database]
engine = "postgres"
host = "postgres"
port = 5432
user = "iris"
password = "$POSTGRES_PASSWORD"
database = "iris"
EOF
fi

# Configuration Velociraptor
if [ ! -f "$CONFIG_DIR/velociraptor/server.config.yaml" ]; then
  cat << EOF > "$CONFIG_DIR/velociraptor/server.config.yaml"
server:
  use_self_signed_ssl: true
  bind_address: $SERVER_IP
  bind_port: 8889
  frontend_host: $SERVER_IP:8889
  
datastore:
  implementation: Elastic

elastic:
  urls: ["http://10.0.50.2:9200"]  # SIEM-01
  index: "velociraptor"
  username: "velociraptor"
  password: "$(generate_password)"

client:
  server_urls: ["https://$SERVER_IP:8889/"]
  nonce: "$VELOCIRAPTOR_HASH_SECRET"
EOF
fi

# ------------------------------------------------------------------------------
# Installation des Modules
# ------------------------------------------------------------------------------

echo -e "${YELLOW}>>> Installation des modules d'intégration...${NC}"

if [ -f "$MODULES_DIR/install-iris-velociraptor-module.sh" ]; then
  bash "$MODULES_DIR/install-iris-velociraptor-module.sh"
else
  echo -e "${YELLOW}⚠️ Script d'installation des modules non trouvé. Ignoré.${NC}"
fi

# ------------------------------------------------------------------------------
# Démarrage des Containers
# ------------------------------------------------------------------------------

if [[ $1 != "--skip-docker" ]] && [[ $2 != "--skip-docker" ]]; then
  echo -e "${YELLOW}>>> Démarrage des services Docker...${NC}"
  docker compose up -d --build
  
  echo -e "\n${GREEN}>>> Déploiement terminé avec succès!${NC}"
  echo -e "Accès aux services:"
  echo -e "  - IRIS:          http://${SERVER_IP}:8000"
  echo -e "  - Velociraptor:  https://${SERVER_IP}:8889"
  echo -e "  - PostgreSQL:    ${SERVER_IP}:5432"
fi

# ------------------------------------------------------------------------------
# Sécurisation Finale
# ------------------------------------------------------------------------------

echo -e "\n${YELLOW}>>> Sécurisation des accès...${NC}"
chmod 700 "$SECRETS_DIR"
chmod 600 "$SECRETS_DIR"/*

echo -e "${GREEN}Configuration DFIR-02 prête à l'emploi!${NC}"
