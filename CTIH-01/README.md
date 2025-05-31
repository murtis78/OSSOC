# CTIH-01 - MISP & OpenCTI Platform

Configuration complète pour déployer MISP et OpenCTI avec Docker Compose.

## 📋 Architecture

```
ctih-01/
├── docker-compose.yml        # Configuration des services
├── .env                     # Variables d'environnement
├── setup.sh                # Script de configuration automatique
├── README.md               # Documentation
├── configs/                # Fichiers de configuration
│   ├── misp/
│   │   └── config.php      # Configuration MISP
│   └── opencti/
│       └── docker.env      # Variables OpenCTI
├── data/                   # Données persistantes
│   ├── misp/              # Données MISP
│   ├── opencti/           # Logs OpenCTI
│   └── postgres/          # Base de données PostgreSQL
├── certs/                 # Certificats SSL
├── secrets/               # Clés et secrets
└── modules/              # Modules additionnels
```

## 🚀 Services déployés

- **OpenCTI** : Plateforme de threat intelligence
- **MISP** : Malware Information Sharing Platform
- **PostgreSQL** : Base de données pour OpenCTI
- **Redis** : Cache et broker de messages
- **Elasticsearch** : Moteur de recherche pour OpenCTI
- **MinIO** : Stockage d'objets
- **RabbitMQ** : Broker de messages

## ⚡ Installation rapide

### 1. Télécharger les fichiers

Créez la structure et copiez tous les fichiers dans le dossier `ctih-01/`.

### 2. Exécuter le script de configuration

```bash
chmod +x setup.sh
./setup.sh
```

### 3. Démarrer les services

```bash
docker-compose up -d
```

### 4. Vérifier le statut

```bash
docker-compose ps
```

## 🌐 Accès aux interfaces

| Service | URL | Utilisateur | Mot de passe |
|---------|-----|-------------|--------------|
| OpenCTI | http://localhost:8080 | admin@example.com | ChangeMe! |
| MISP | https://localhost | admin@example.com | (voir clé API) |
| MinIO Console | http://localhost:9001 | opencti | (voir .env) |
| RabbitMQ Management | http://localhost:15672 | guest | guest |

## 🔧 Configuration manuelle

### Variables d'environnement (.env)

```bash
# OpenCTI
OPENCTI_ADMIN_EMAIL=admin@example.com
OPENCTI_ADMIN_PASSWORD=ChangeMe!
OPENCTI_SECRET=<généré automatiquement>

# Base de données
POSTGRES_PASSWORD=<généré automatiquement>

# MISP
MISP_ADMIN_KEY=<généré automatiquement>
MISP_DB_PASSWORD=<généré automatiquement>
```

### Première connexion MISP

1. Accédez à https://localhost
2. Utilisateur : `admin@admin.test`
3. Mot de passe : `admin` (à changer immédiatement)
4. Allez dans Administration → Server Settings & Maintenance
5. Configurez l'URL de base et l'email

### Configuration OpenCTI

1. Accédez à http://localhost:8080
2. Connectez-vous avec les identifiants de l'admin
3. Allez dans Settings → Parameters
4. Configurez les connecteurs MISP si nécessaire

## 🔗 Intégration MISP/OpenCTI

### Configuration du connecteur MISP dans OpenCTI

1. Dans OpenCTI, allez dans Data → Connectors
2. Ajoutez un nouveau connecteur MISP
3. URL MISP : `https://misp/`
4. Clé API : utilisez `MISP_ADMIN_KEY` du fichier `.env`
5. Activez la synchronisation

### Configuration des feeds dans MISP

1. Dans MISP, allez dans Sync Actions → List Feeds
2. Ajoutez des feeds de threat intelligence
3. Configurez la synchronisation automatique

## 📊 Monitoring et logs

### Suivre les logs

```bash
# Tous les services
docker-compose logs -f

# Service spécifique
docker-compose logs -f opencti
docker-compose logs -f misp
```

### Vérifier l'état des services

```bash
# État des conteneurs
docker-compose ps

# Utilisation des ressources
docker stats

# Espace disque
docker system df
```

## 🔒 Sécurité

### Actions importantes après installation

1. **Changer les mots de passe par défaut**
   - OpenCTI admin
   - MISP admin
   - Base de données

2. **Configurer HTTPS proprement**
   - Remplacer les certificats auto-signés
   - Configurer un reverse proxy (Nginx/Traefik)

3. **Sauvegarder les clés**
   - Fichier `secrets/keys.txt` généré automatiquement
   - Conserver une copie sécurisée hors du serveur

4. **Configurer le pare-feu**
   ```bash
   # Exemple avec ufw
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 8080/tcp
   ```

5. **Mettre en place des sauvegardes régulières**
   ```bash
   # Script de sauvegarde exemple
   docker-compose exec postgres pg_dump -U opencti opencti > backup_opencti_$(date +%Y%m%d).sql
   ```

## 🛠️ Maintenance

### Mise à jour des services

```bash
# Arrêter les services
docker-compose down

# Mettre à jour les images
docker-compose pull

# Redémarrer
docker-compose up -d
```

### Sauvegarde des données

```bash
# Créer un script de sauvegarde
./backup.sh
```

### Nettoyage

```bash
# Nettoyer les images inutilisées
docker system prune -a

# Voir l'utilisation disque
docker system df
```

## 🐛 Résolution de problèmes

### Problèmes courants

#### OpenCTI ne démarre pas
- Vérifier les logs : `docker-compose logs opencti`
- S'assurer que PostgreSQL est démarré
- Vérifier les variables d'environnement

#### MISP inaccessible
- Vérifier les certificats SSL dans `certs/`
- Contrôler les logs : `docker-compose logs misp`
- Vérifier la configuration MySQL

#### Erreurs de base de données
```bash
# Réinitialiser PostgreSQL
docker-compose down
docker volume rm ctih_postgres_data
docker-compose up -d postgres
```

#### Problèmes de mémoire
- Augmenter la mémoire allouée à Elasticsearch
- Ajuster `NODE_OPTIONS` pour OpenCTI

### Commandes utiles

```bash
# Redémarrer un service
docker-compose restart opencti

# Accéder au shell d'un conteneur
docker-compose exec opencti bash
docker-compose exec misp bash

# Voir les processus
docker-compose top

# Statistiques en temps réel
docker stats
```

## 📈 Optimisation des performances

### Configuration Elasticsearch

```yaml
# Dans docker-compose.yml
environment:
  - "ES_JAVA_OPTS=-Xms1g -Xmx1g"  # Ajuster selon RAM disponible
```

### Configuration PostgreSQL

Ajoutez des variables d'optimisation :

```yaml
environment:
  - POSTGRES_SHARED_PRELOAD_LIBRARIES=pg_stat_statements
  - POSTGRES_MAX_CONNECTIONS=200
  - POSTGRES_SHARED_BUFFERS=256MB
```

### Configuration Redis

```yaml
command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru
```

## 🔧 Configuration avancée

### Proxy inverse avec Nginx

Créez un fichier `nginx.conf` :

```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    location /opencti/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /misp/ {
        proxy_pass https://localhost/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Monitoring avec Prometheus

Ajoutez au `docker-compose.yml` :

```yaml
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - ctih_network

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    networks:
      - ctih_network
```

## 📚 Ressources additionnelles

### Documentation officielle
- [MISP Documentation](https://www.misp-project.org/documentation/)
- [OpenCTI Documentation](https://docs.opencti.io/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

### Communauté
- [MISP GitHub](https://github.com/MISP/MISP)
- [OpenCTI GitHub](https://github.com/OpenCTI-Platform/opencti)
- [Forums de sécurité](https://www.reddit.com/r/cybersecurity/)

## 📝 Changelog

### Version 1.0
- Configuration initiale MISP + OpenCTI
- Script d'installation automatique
- Documentation complète
- Certificats SSL auto-signés

### Améliorations prévues
- [ ] Intégration LDAP/SSO
- [ ] Monitoring avancé
- [ ] Sauvegardes automatisées
- [ ] Certificats Let's Encrypt
- [ ] API de configuration

## 🤝 Contribution

Pour contribuer à ce projet :
1. Fork le repository
2. Créez une branche pour votre feature
3. Commitez vos changements
4. Poussez vers la branche
5. Ouvrez une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.

## ⚠️ Avertissements

- Cette configuration est destinée à un environnement de développement/test
- Pour la production, renforcez la sécurité (HTTPS, pare-feu, etc.)
- Changez TOUS les mots de passe par défaut
- Mettez en place des sauvegardes régulières
- Surveillez les logs de sécurité

---

**Maintenu par** : Équipe CTIH  
**Dernière mise à jour** : $(date +%Y-%m-%d)  
**Version** : 1.0