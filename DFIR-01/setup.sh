#!/bin/bash

# Script de configuration DFIR Stack
# Créer la structure de répertoires et initialiser l'environnement

set -e

echo "=== Configuration DFIR Stack ==="
echo "TheHive + Cortex + Shuffle + Redis"
echo ""

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier si Docker et Docker Compose sont installés
if ! command -v docker &> /dev/null; then
    log_error "Docker n'est pas installé"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose n'est pas installé"
    exit 1
fi

# Créer la structure de répertoires
log_info "Création de la structure de répertoires..."

mkdir -p dfir-01/{configs/{thehive,cortex,shuffle},data/{thehive,cortex,redis,shuffle},certs,secrets,modules}

# Créer les répertoires de données avec les bonnes permissions
sudo chown -R 1000:1000 dfir-01/data/
sudo chmod -R 755 dfir-01/data/

# Créer les répertoires de configuration
sudo chown -R 1000:1000 dfir-01/configs/
sudo chmod -R 644 dfir-01/configs/

log_info "Structure de répertoires créée ✓"

# Générer des secrets aléatoirement
log_info "Génération des secrets..."

THEHIVE_SECRET=$(openssl rand -hex 32)
CORTEX_SECRET=$(openssl rand -hex 32)
REDIS_PASSWORD=$(openssl rand -hex 16)
SHUFFLE_API_KEY=$(openssl rand -hex 32)
CORTEX_API_KEY=$(openssl rand -hex 32)

# Créer le fichier .env avec les vraies valeurs
cat > dfir-01/.env << EOF
# DFIR Stack Environment Variables
# Secrets générés automatiquement
THEHIVE_SECRET=${THEHIVE_SECRET}
CORTEX_SECRET=${CORTEX_SECRET}
REDIS_PASSWORD=${REDIS_PASSWORD}
SHUFFLE_API_KEY=${SHUFFLE_API_KEY}

# Clés API pour l'intégration TheHive-Cortex
CORTEX_API_KEY=${CORTEX_API_KEY}

# Configuration réseau
DFIR_NETWORK_SUBNET=172.20.0.0/16

# Ports d'exposition
THEHIVE_PORT=9000
CORTEX_PORT=9001
SHUFFLE_PORT=3001
REDIS_PORT=6379

# Chemins de données
DATA_PATH=./data
CONFIG_PATH=./configs
CERTS_PATH=./certs
SECRETS_PATH=./secrets
MODULES_PATH=./modules

# Configuration avancée
REDIS_MAX_MEMORY=2gb
REDIS_MAX_MEMORY_POLICY=allkeys-lru

# Timezone
TZ=Europe/Paris
EOF

log_info "Fichier .env créé avec des secrets générés ✓"

# Créer des certificats auto-signés pour les tests
log_info "Génération des certificats SSL de test..."

cd dfir-01/certs/

# Générer une clé privée et un certificat auto-signé
openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes \
    -subj "/C=FR/ST=IDF/L=Paris/O=DFIR/OU=Security/CN=localhost"

# Créer un certificat combiné
cat server.crt server.key > server.pem

log_info "Certificats SSL générés ✓"

cd ..

# Télécharger les modules Cortex de base
log_info "Téléchargement des modules Cortex..."

mkdir -p modules/yara-rules
cd modules/

# Télécharger les règles Yara
if command -v git &> /dev/null; then
    git clone https://github.com/Yara-Rules/rules.git yara-rules/ || log_warn "Impossible de télécharger les règles Yara"
else
    log_warn "Git non installé, règles Yara non téléchargées"
fi

cd ..

# Créer un script de démarrage
cat > start.sh << 'EOF'
#!/bin/bash

echo "=== Démarrage DFIR Stack ==="

# Vérifier que le fichier .env existe
if [ ! -f .env ]; then
    echo "Erreur: Fichier .env manquant"
    echo "Exécutez d'abord le script setup.sh"
    exit 1
fi

# Démarrer les services
echo "Démarrage des services..."
docker-compose up -d

# Attendre que les services soient prêts
echo "Attente du démarrage des services..."
sleep 30

# Afficher le statut
docker-compose ps

echo ""
echo "=== Services disponibles ==="
echo "TheHive:  http://localhost:9000"
echo "Cortex:   http://localhost:9001"
echo "Shuffle:  http://localhost:3001"
echo "Redis:    localhost:6379"
echo ""
echo "Comptes par défaut:"
echo "TheHive: admin@thehive.local / secret"
echo "Cortex:  admin@cortex.local / secret"
echo ""
echo "Pour arrêter: docker-compose down"
echo "Pour voir les logs: docker-compose logs -f [service]"
EOF

chmod +x start.sh

# Créer un script d'arrêt
cat > stop.sh << 'EOF'
#!/bin/bash

echo "=== Arrêt DFIR Stack ==="
docker-compose down

echo "Services arrêtés ✓"
EOF

chmod +x stop.sh

# Créer un script de sauvegarde
cat > backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
echo "=== Sauvegarde DFIR Stack ==="
echo "Répertoire de sauvegarde: $BACKUP_DIR"

# Arrêter les services
docker-compose down

# Créer la sauvegarde
mkdir -p "$BACKUP_DIR"
cp -r data/ "$BACKUP_DIR/"
cp -r configs/ "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/"
cp docker-compose.yml "$BACKUP_DIR/"

# Créer une archive
tar -czf "${BACKUP_DIR}.tar.gz" "$BACKUP_DIR/"
rm -rf "$BACKUP_DIR/"

echo "Sauvegarde créée: ${BACKUP_DIR}.tar.gz ✓"

# Redémarrer les services
docker-compose up -d
EOF

chmod +x backup.sh

log_info "Scripts de gestion créés ✓"

echo ""
echo "=== Configuration terminée ==="
echo ""
echo "Structure créée dans: $(pwd)/dfir-01/"
echo ""
echo "Prochaines étapes:"
echo "1. cd dfir-01/"
echo "2. Vérifiez les configurations dans configs/"
echo "3. Ajustez les clés API dans .env si nécessaire"
echo "4. Lancez: ./start.sh"
echo ""
echo "URLs des services:"
echo "• TheHive:  http://localhost:9000"
echo "• Cortex:   http://localhost:9001"  
echo "• Shuffle:  http://localhost:3001"
echo ""
echo "Documentation:"
echo "• TheHive: https://docs.thehive-project.org/"
echo "• Cortex:  https://github.com/TheHive-Project/Cortex"
echo "• Shuffle: https://shuffler.io/docs/"
echo ""

log_info "Configuration DFIR Stack terminée avec succès !"