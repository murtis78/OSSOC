# Stack SIEM Complète
## Wazuh + OpenSearch + Graylog

Cette stack SIEM fournit une solution complète de sécurité et de monitoring avec Wazuh, OpenSearch et Graylog, configurés avec TLS et optimisés pour la production.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Wazuh Manager  │    │ Wazuh Dashboard │    │   Wazuh Agent   │
│     :55000      │◄──►│      :443       │    │   (externe)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Wazuh Indexer   │    │   OpenSearch    │    │    Graylog      │
│     :9201       │    │     :9200       │    │     :9000       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                └───────────────────────┘
                                         │
                                ┌─────────────────┐
                                │    MongoDB      │
                                │     :27017      │
                                └─────────────────┘
```

## 📦 Composants

| Service | Version | Port | Description |
|---------|---------|------|-------------|
| **Wazuh Manager** | 4.7.4 | 55000, 1514 | Moteur de détection et analyse |
| **Wazuh Indexer** | 4.7.4 | 9201 | Index des données Wazuh |
| **Wazuh Dashboard** | 4.7.4 | 443 | Interface web Wazuh |
| **OpenSearch** | 2.12.0 | 9200 | Moteur de recherche principal |
| **Graylog** | 5.2 | 9000 | Centralisation et analyse des logs |
| **MongoDB** | 7.0 | 27017 | Base de données Graylog |

## 🚀 Installation Rapide

### Prérequis
```bash
# Docker & Docker Compose
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Outils système
sudo apt-get update
sudo apt-get install -y openssl pwgen
```

### Déploiement
```bash
# Cloner la configuration
git clone <repository>
cd siem-02/

# Rendre le script exécutable
chmod +x setup.sh

# Installation complète
./setup.sh
```

## 🔧 Configuration Détaillée

### Variables d'Environnement (.env)
```bash
# Sécurité - À CHANGER EN PRODUCTION
WAZUH_API_USER=admin
WAZUH_API_PASS=VotreMotDePasseSecurise!
GRAYLOG_ADMIN_PWD=VotreMotDePasseSecurise!
OPENSEARCH_ADMIN_PWD=VotreMotDePasseSecurise!

# Base de données
MONGO_ROOT_USER=admin
MONGO_ROOT_PASSWORD=VotreMotDePasseSecurise!
```

### Structure des Dossiers
```
siem-02/
├── docker-compose.yml          # Configuration principale
├── .env                        # Variables d'environnement
├── setup.sh                   # Script d'installation
├── configs/                   # Configurations des services
│   ├── wazuh/
│   │   └── ossec.conf         # Configuration Wazuh Manager
│   ├── opensearch/
│   │   └── opensearch.yml     # Configuration OpenSearch
│   └── graylog/
│       └── graylog.conf       # Configuration Graylog
├── data/                      # Données persistantes
│   ├── wazuh-indexer/
│   ├── opensearch/
│   ├── graylog/
│   ├── mongo/
│   └── wazuh/
├── certs/                     # Certificats TLS
├── secrets/                   # Secrets et clés
└── modules/                   # Templates et dashboards
    ├── dashboards/
    ├── templates/
    └── content-packs/
```

## 🔐 Sécurité TLS

### Génération des Certificats
```bash
# Automatique via le script
./setup.sh certificates

# Manuel
cd certs/
openssl genrsa -out root-ca-key.pem 2048
openssl req -new -x509 -sha256 -key root-ca-key.pem -out root-ca.pem -days 365
# ... autres certificats
```

### Configuration SSL/TLS
- **Chiffrement** : Toutes les communications inter-services
- **Authentification** : Certificats mutuels
- **Algorithmes** : RSA 2048 bits, SHA-256

## 🎯 Utilisation

### Accès aux Interfaces

#### Wazuh Dashboard
```
URL: https://localhost:443
Utilisateur: admin
Mot de passe: ChangeMe!
```

#### Graylog
```
URL: http://localhost:9000
Utilisateur: admin  
Mot de passe: ChangeMe!
```

#### OpenSearch
```
URL: https://localhost:9200
Utilisateur: admin
Mot de passe: ChangeMe!
```

### Commandes Utiles

```bash
# État des services
./setup.sh status
docker-compose ps

# Logs en temps réel
./setup.sh logs [service]
docker-compose logs -f wazuh-manager

# Redémarrage d'un service
docker-compose restart graylog

# Arrêt complet
./setup.sh stop
docker-compose down

# Nettoyage complet (⚠️ SUPPRIME LES DONNÉES)
./setup.sh clean
```

## 📊 Intégrations

### Wazuh → OpenSearch
- Index automatique des alertes Wazuh
- Dashboards de sécurité préconfigurés
- Corrélation d'événements avancée

### Graylog → OpenSearch  
- Stockage centralisé des logs
- Recherche unifiée
- Archivage long terme

### Agents Wazuh
```bash
# Installation agent Linux
curl -s https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.4-1_amd64.deb
sudo dpkg -i wazuh-agent_4.7.4-1_amd64.deb

# Configuration
sudo sed -i 's/MANAGER_IP/YOUR_WAZUH_MANAGER_IP/' /var/ossec/etc/ossec.conf
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
```

## 📈 Monitoring et Performance

### Métriques Système
```bash
# Utilisation des ressources
docker stats

# Santé des services
curl -k https://localhost:9200/_cluster/health
curl http://localhost:9000/api/system
```

### Optimisation
- **Mémoire** : 8GB minimum recommandés
- **CPU** : 4 cores minimum
- **Stockage** : SSD recommandé
- **Réseau** : 1Gbps pour la collecte intensive

## 🔍 Dépannage

### Problèmes Courants

#### Services qui ne démarrent pas
```bash
# Vérifier les logs
docker-compose logs [service]

# Vérifier les permissions
sudo chown -R 1000:1000 data/opensearch/
sudo chmod 777 data/graylog/
```

#### Problèmes de certificats
```bash
# Régénérer les certificats
rm -rf certs/*
./setup.sh certificates
docker-compose restart
```

#### Problèmes de mémoire
```bash
# Augmenter vm.max_map_count
sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
```

### Logs Utiles
```bash
# Wazuh Manager
docker-compose logs wazuh-manager

# OpenSearch
docker-compose logs opensearch

# Graylog
docker-compose logs graylog
```

## 🔄 Sauvegarde et Restauration

### Sauvegarde
```bash
# Arrêt des services
docker-compose stop

# Sauvegarde des données
tar -czf backup-$(date +%Y%m%d).tar.gz data/ configs/ certs/

# Redémarrage
docker-compose start
```

### Restauration
```bash
# Arrêt et nettoyage
docker-compose down -v

# Restauration
tar -xzf backup-YYYYMMDD.tar.gz

# Redémarrage
./setup.sh start
```

## 📝 Maintenance

### Rotation des Logs
```bash
# Configuration dans opensearch.yml
action.auto_create_index: +*
indices.query.bool.max_clause_count: 1024
```

### Nettoyage des Index
```bash
# Script de nettoyage automatique (à programmer via cron)
curl -X DELETE "https://localhost:9200/wazuh-alerts-$(date -d '30 days ago' +%Y.%m.%d)"
```

## 🤝 Support

### Documentation Officielle
- [Wazuh Documentation](https://documentation.wazuh.com/)
- [OpenSearch Documentation](https://opensearch.org/docs/)
- [Graylog Documentation](https://docs.graylog.org/)

### Communauté
- Issues GitHub
- Forums officiels
- Discord/Slack des projets

## 📄 Licence

Cette configuration est fournie sous licence MIT. Voir les licences individuelles des composants :
- Wazuh : GPL v2
- OpenSearch : Apache 2.0
- Graylog : Server Side Public License (SSPL)