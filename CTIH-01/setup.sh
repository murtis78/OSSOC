#!/bin/bash

# Script de configuration pour l'environnement CTIH-01
# MISP + OpenCTI + PostgreSQL

echo "🚀 Configuration de l'environnement CTIH-01..."

# Création de la structure des dossiers
echo "📁 Création de la structure des dossiers..."
mkdir -p ctih-01/{configs/{misp,opencti},data/{misp,opencti,postgres},certs,secrets,modules}

# Déplacement dans le répertoire de travail
cd ctih-01

# Génération des clés secrètes
echo "🔑 Génération des clés secrètes..."
OPENCTI_SECRET=$(openssl rand -hex 32)
MISP_ADMIN_KEY=$(openssl rand -hex 32)
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
MISP_DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
MISP_DB_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Mise à jour du fichier .env avec les vraies clés
echo "📝 Configuration du fichier .env..."
sed -i "s/SECRET_KEY_CHANGE_THIS_TO_RANDOM_STRING_32_CHARS/$OPENCTI_SECRET/g" .env
sed -i "s/SECRET_MISP_KEY_CHANGE_THIS_TO_RANDOM_STRING/$MISP_ADMIN_KEY/g" .env
sed -i "s/DB_Password/$POSTGRES_PASSWORD/g" .env
sed -i "s/MISP_DB_Password_ChangeMe/$MISP_DB_PASSWORD/g" .env
sed -i "s/MISP_DB_Root_Password_ChangeMe/$MISP_DB_ROOT_PASSWORD/g" .env

# Mise à jour du fichier docker.env OpenCTI
echo "🔧 Configuration d'OpenCTI..."
sed -i "s/SECRET_KEY_CHANGE_THIS_TO_RANDOM_STRING_32_CHARS/$OPENCTI_SECRET/g" configs/opencti/docker.env
sed -i "s/DB_Password/$POSTGRES_PASSWORD/g" configs/opencti/docker.env
sed -i "s/SECRET_MISP_KEY_CHANGE_THIS_TO_RANDOM_STRING/$MISP_ADMIN_KEY/g" configs/opencti/docker.env

# Génération des certificats SSL auto-signés pour MISP
echo "🔐 Génération des certificats SSL..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout certs/misp.key \
    -out certs/misp.crt \
    -subj "/C=FR/ST=IDF/L=Paris/O=CTIH/OU=Security/CN=localhost"

# Configuration des permissions
echo "🔒 Configuration des permissions..."
chmod 600 certs/misp.key
chmod 644 certs/misp.crt
chmod 600 .env
chmod 600 configs/opencti/docker.env

# Affichage des informations importantes
echo ""
echo "✅ Configuration terminée !"
echo ""
echo "📋 Informations importantes :"
echo "   - Email admin : admin@example.com"
echo "   - Mot de passe OpenCTI : ChangeMe!"
echo "   - Clé MISP : $MISP_ADMIN_KEY"
echo ""
echo "🌐 URLs d'accès :"
echo "   - OpenCTI : http://localhost:8080"
echo "   - MISP : https://localhost (ou http://localhost)"
echo "   - MinIO Console : http://localhost:9001"
echo "   - RabbitMQ Management : http://localhost:15672"
echo ""
echo "🚀 Pour démarrer les services :"
echo "   docker-compose up -d"
echo ""
echo "📊 Pour suivre les logs :"
echo "   docker-compose logs -f"
echo ""
echo "⚠️  N'oubliez pas de :"
echo "   1. Changer les mots de passe par défaut"
echo "   2. Configurer la communication MISP/OpenCTI"
echo "   3. Sauvegarder vos clés secrètes"

# Création d'un fichier de sauvegarde des clés
echo "💾 Sauvegarde des clés dans secrets/keys.txt..."
cat > secrets/keys.txt << EOF
# Clés générées le $(date)
OPENCTI_SECRET=$OPENCTI_SECRET
MISP_ADMIN_KEY=$MISP_ADMIN_KEY
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
MISP_DB_PASSWORD=$MISP_DB_PASSWORD
MISP_DB_ROOT_PASSWORD=$MISP_DB_ROOT_PASSWORD
EOF

chmod 600 secrets/keys.txt

echo ""
echo "🔐 Les clés ont été sauvegardées dans secrets/keys.txt"
echo "🚨 IMPORTANT : Gardez ce fichier en sécurité !"