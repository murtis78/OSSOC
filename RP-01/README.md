# NGiNX Proxy Manager avec Let's Encrypt

Configuration complète pour NGiNX Proxy Manager avec support SSL/TLS et Let's Encrypt.

## Structure du projet

```
./rp-01/
├── docker-compose.yml
├── .env
├── configs/
│   └── nginx-proxy-manager/
│       ├── production.json
│       └── default.conf
├── data/                    # Données persistantes NPM
├── certs/                   # Certificats Let's Encrypt
├── secrets/                 # Certificats SSL personnalisés
│   └── ssl/
└── modules/                 # Modules personnalisés
```

## Installation rapide

### 1. Préparation de l'environnement

```bash
# Créer la structure des dossiers
mkdir -p rp-01/{configs/nginx-proxy-manager,data,certs,secrets/ssl,modules}
cd rp-01

# Copier les fichiers de configuration
# (docker-compose.yml, .env, configs/)
```

### 2. Configuration initiale

```bash
# Modifier le fichier .env avec vos paramètres
nano .env

# Paramètres à modifier obligatoirement :
# - NPM_INIT_EMAIL=votre@email.com
# - NPM_INIT_PWD=VotreMotDePasseSecurise
# - LETSENCRYPT_EMAIL=votre@email.com
```

### 3. Génération des certificats OpenSSL par défaut

```bash
# Certificat auto-signé pour le serveur par défaut
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout secrets/ssl/default.key \
  -out secrets/ssl/default.crt \
  -subj "/C=FR/ST=Ile-de-France/L=Paris/O=MyOrganization/OU=IT Department/CN=localhost"

# Certificat wildcard pour développement (optionnel)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout secrets/ssl/wildcard.key \
  -out secrets/ssl/wildcard.crt \
  -subj "/C=FR/ST=Ile-de-France/L=Paris/O=MyOrganization/OU=IT Department/CN=*.local.dev"

# Définir les permissions correctes
chmod 600 secrets/ssl/*.key
chmod 644 secrets/ssl/*.crt
```

### 4. Démarrage des services

```bash
# Démarrer NGiNX Proxy Manager
docker-compose up -d

# Vérifier les logs
docker-compose logs -f npm
```

### 5. Configuration initiale via interface web

1. Accéder à l'interface admin : `http://votre-ip:81`
2. Se connecter avec :
   - Email : `admin@example.com` (ou celui défini dans .env)
   - Mot de passe : `changeme` (ou celui défini dans .env)
3. Changer immédiatement les identifiants par défaut
4. Configurer vos domaines et certificats Let's Encrypt

## Commandes OpenSSL utiles

### Génération de certificats personnalisés

```bash
# Certificat avec SAN (Subject Alternative Names)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout secrets/ssl/mydomain.key \
  -out secrets/ssl/mydomain.crt \
  -config <(
    echo '[dn]'
    echo 'CN=mydomain.com'
    echo '[req]'
    echo 'distinguished_name = dn'
    echo '[alt_names]'
    echo 'DNS.1=mydomain.com'
    echo 'DNS.2=*.mydomain.com'
    echo 'DNS.3=api.mydomain.com'
  ) \
  -extensions alt_names

# Certificat avec clé ECC (plus rapide)
openssl ecparam -genkey -name secp384r1 -out secrets/ssl/ecc.key
openssl req -new -x509 -sha256 -key secrets/ssl/ecc.key \
  -out secrets/ssl/ecc.crt -days 365 \
  -subj "/C=FR/ST=Ile-de-France/L=Paris/O=MyOrganization/CN=mydomain.com"
```

### Vérification des certificats

```bash
# Vérifier un certificat
openssl x509 -in secrets/ssl/mydomain.crt -text -noout

# Vérifier la correspondance clé/certificat
openssl rsa -in secrets/ssl/mydomain.key -modulus -noout | openssl md5
openssl x509 -in secrets/ssl/mydomain.crt -modulus -noout | openssl md5

# Tester la connexion SSL
openssl s_client -connect mydomain.com:443 -servername mydomain.com
```

### Conversion de formats

```bash
# PEM vers PKCS#12
openssl pkcs12 -export -out secrets/ssl/certificate.p12 \
  -inkey secrets/ssl/mydomain.key \
  -in secrets/ssl/mydomain.crt

# PKCS#12 vers PEM
openssl pkcs12 -in secrets/ssl/certificate.p12 -out secrets/ssl/certificate.pem -nodes
```

## Scripts utiles

### Script de backup automatique

```bash
#!/bin/bash
# Sauvegarder les données NPM
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf backups/npm_backup_$DATE.tar.gz data/ certs/ secrets/
find backups/ -name "npm_backup_*.tar.gz" -mtime +30 -delete
```

### Script de monitoring SSL

```bash
#!/bin/bash
# Vérifier l'expiration des certificats
for cert in secrets/ssl/*.crt; do
  echo "=== $cert ==="
  openssl x509 -in "$cert" -noout -dates
  echo
done
```

## Dépannage

### Problèmes courants

1. **Port 80/443 déjà utilisé** :
   ```bash
   sudo netstat -tlnp | grep :80
   sudo systemctl stop apache2 nginx
   ```

2. **Permissions des certificats** :
   ```bash
   sudo chown -R 1000:1000 secrets/
   chmod 600 secrets/ssl/*.key
   ```

3. **Base de données corrompue** :
   ```bash
   docker-compose stop
   rm data/database.sqlite
   docker-compose up -d
   ```

### Logs et monitoring

```bash
# Logs NPM
docker-compose logs -f npm

# Logs NGiNX
docker exec nginx-proxy-manager tail -f /var/log/nginx/access.log
docker exec nginx-proxy-manager tail -f /var/log/nginx/error.log

# Monitoring des certificats Let's Encrypt
docker exec nginx-proxy-manager certbot certificates
```

## Sécurité

### Recommandations

1. Changer les mots de passe par défaut
2. Utiliser des certificats forts (RSA 2048+ ou ECC 256+)
3. Activer HSTS et OCSP Stapling
4. Configurer le rate limiting
5. Mettre à jour régulièrement les images Docker
6. Sauvegarder régulièrement les données

### Configuration firewall

```bash
# UFW (Ubuntu)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 81/tcp  # Admin (restreindre aux IPs autorisées)

# iptables
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 81 -s IP_ADMIN -j ACCEPT
```

## Maintenance

### Mise à jour

```bash
# Mise à jour de l'image
docker-compose pull
docker-compose up -d

# Nettoyage
docker system prune -f
```

### Monitoring

```bash
# État des containers
docker-compose ps

# Utilisation des ressources
docker stats nginx-proxy-manager

# Santé du service
curl -f http://localhost:81/api || echo "Service down"
```