# 🛡️ Stack SIEM Elastic - Configuration Complète

Une stack SIEM (Security Information and Event Management) complète basée sur Elastic Stack 8.12.2 avec configuration TLS, Fleet Server intégré, et pipelines optimisés pour la sécurité.

## 📋 Table des matières

- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Monitoring](#monitoring)
- [Sécurité](#sécurité)
- [Dépannage](#dépannage)

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Agents      │    │    Logstash     │    │ Elasticsearch   │
│                 │    │                 │    │                 │
│ • Winlogbeat    │───▶│ • Parsing       │───▶│ • Storage       │
│ • Filebeat      │    │ • Enrichment    │    │ • Indexing      │
│ • Wazuh         │    │ • GeoIP         │    │ • Search        │
│ • Fleet Agents  │    │ • Correlation   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                       ┌─────────────────┐             │
                       │     Kibana      │◀────────────┘
                       │                 │
                       │ • SIEM          │
                       │ • Fleet         │
                       │ • Dashboards    │
                       │ • Alerting      │
                       └─────────────────┘
```

## 📁 Structure du projet

```
siem-01/
├── docker-compose.yml          # Configuration Docker Compose
├── .env                        # Variables d'environnement
├── setup.sh                    # Script d'installation automatisée
├── README.md                   # Ce fichier
├── configs/                    # Fichiers de configuration
│   ├── elasticsearch/
│   │   └── elasticsearch.yml
│   ├── logstash/
│   │   ├── logstash.yml
│   │   └── logstash.conf      # Pipeline principal
│   └── kibana/
│       └── kibana.yml
├── data/                       # Données persistantes
│   ├── esdata/                # Données Elasticsearch
│   └── logstash-data/         # Données Logstash
├── certs/                      # Certificats SSL/TLS
│   ├── ca/                    # Autorité de certification
│   ├── elasticsearch/         # Certificats Elasticsearch
│   ├── kibana/               # Certificats Kibana
│   └── logstash/             # Certificats Logstash
├── secrets/                    # Fichiers secrets
└── modules/                    # Modules Logstash personnalisés
```

## ⚙️ Prérequis

### Système
- **OS**: Linux (Ubuntu 20.04+, CentOS 8+, RHEL 8+)
- **RAM**: Minimum 8GB (16GB recommandé)
- **CPU**: 4 cores minimum
- **Stockage**: 50GB minimum (SSD recommandé)

### Logiciels requis
```bash
# Docker
sudo apt update
sudo apt install -y docker.io docker-compose

# Ou via le script officiel Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

### Configuration système
```bash
# Augmenter la limite de mémoire virtuelle pour Elasticsearch
sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf

# Augmenter les limites de fichiers ouverts
echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf
echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf
```

## 🚀 Installation

### 1. Clonage et préparation

```bash
# Créer le répertoire du projet
mkdir -p ~/siem-01 && cd ~/siem-01

# Copier les fichiers de configuration
# (docker-compose.yml, .env, configs/, etc.)
```

### 2. Configuration des variables

Éditez le fichier `.env` :

```bash
# Mots de passe (CHANGEZ-LES !)
ELASTIC_PASSWORD=VotreMotDePasseFort123!
KIBANA_SYSTEM_PASSWORD=VotreAutreMotDePasse456!
LOGSTASH_SYSTEM_PASSWORD=EncoreUnAutreMotDePasse789!

# Clé de chiffrement Kibana (générer avec: openssl rand -hex 32)
KIBANA_ENCRYPTION_KEY=votre_cle_de_chiffrement_64_caracteres_hexadecimaux
```

### 3. Installation automatisée

```bash
# Rendre le script exécutable
chmod +x setup.sh

# Installation complète automatique
./setup.sh --auto

# Ou installation interactive
./setup.sh
```

### 4. Installation manuelle

```bash
# 1. Créer la structure des dossiers
mkdir -p {data/esdata,data/logstash-data,certs,secrets,modules}
mkdir -p {configs/elasticsearch,configs/logstash,configs/kibana}

# 2. Configurer les permissions
sudo chown -R 1000:1000 data/esdata certs

# 3. Générer les certificats SSL
docker-compose up setup

# 4. Démarrer Elasticsearch
docker-compose up -d elasticsearch

# 5. Attendre qu'Elasticsearch soit prêt
until curl -s -k https://localhost:9200 | grep -q "missing authentication credentials"; do
    sleep 5
done

# 6. Démarrer les autres services
docker-compose up -d logstash kibana
```

## 🔧 Configuration

### Elasticsearch

Le cluster est configuré avec :
- **Sécurité** : TLS activé, authentification requise
- **Monitoring** : Collecte des métriques activée
- **Machine Learning** : Détection d'anomalies
- **Index Lifecycle Management** : Gestion automatique des index

### Logstash

Pipelines configurés pour :
- **Beats** : Port 5044 (Winlogbeat, Filebeat, etc.)
- **Wazuh** : Port 5045 (alertes HIDS)
- **Syslog** : Port 5514 (logs système)
- **JSON HTTP** : Port 8080 (logs applicatifs)

Enrichissements automatiques :
- **GeoIP** : Géolocalisation des IP
- **DNS** : Résolution des noms d'hôtes
- **Parsing** : Extraction de champs structurés
- **Corrélation** : Scores de sévérité

### Kibana

Fonctionnalités activées :
- **Security Solution** : SIEM complet
- **Fleet Management** : Gestion des agents
- **Machine Learning** : Détection d'anomalies
- **Alerting** : Notifications automatiques
- **Canvas** : Visualisations personnalisées

## 📊 Utilisation

### Accès aux interfaces

| Service | URL | Utilisateur | Mot de passe |
|---------|-----|-------------|--------------|
| Kibana | http://localhost:5601 | elastic | Configuré dans .env |
| Elasticsearch | https://localhost:9200 | elastic | Configuré dans .env |
| Logstash Monitoring | http://localhost:9600 | - | - |

### Configuration des agents

#### Winlogbeat (Windows)

```yaml
# winlogbeat.yml
output.logstash:
  hosts: ["your-siem-server:5044"]

winlogbeat.event_logs:
  - name: Security
    event_id: 4624, 4625, 4648, 4672, 4720, 4722, 4726, 4728, 4732, 4756
  - name: System
  - name: Application
  - name: Microsoft-Windows-PowerShell/Operational
```

#### Wazuh Agent

```xml
<!-- ossec.conf -->
<ossec_config>
  <client>
    <server>
      <address>your-siem-server</address>
      <port>1514</port>
    </server>
  </client>
  
  <localfile>
    <log_format>json</log_format>
    <location>/var/log/auth.log</location>
  </localfile>
</ossec_config>
```

#### Fleet Agent (Elastic Agent)

1. Accédez à Kibana → Fleet
2. Créez une nouvelle politique d'agent
3. Ajoutez les intégrations nécessaires :
   - **System** : Métriques système et logs
   - **Windows** : Logs Windows spécifiques
   - **Endpoint Security** : Protection endpoint

### Dashboards SIEM

Dashboards pré-configurés :
- **Security Overview** : Vue d'ensemble sécurité
- **Network Security** : Monitoring réseau
- **Host Security** : Surveillance des hôtes
- **User Activity** : Activité utilisateurs
- **Threat Hunting** : Chasse aux menaces

### Règles de détection

Exemples de règles personnalisées :

```json
{
  "rule": {
    "name": "Failed Logon Attempts",
    "description": "Détection de tentatives de connexion échouées multiples",
    "risk_score": 75,
    "severity": "high",
    "type": "query",
    "query": "winlog.event_id:4625 AND source.ip:* AND winlog.event_data.FailureReason:*",
    "filters": [
      {
        "range": {
          "@timestamp": {
            "gte": "now-5m"
          }
        }
      }
    ],
    "threshold": {
      "field": "source.ip",
      "value": 5
    }
  }
}
```

## 📈 Monitoring

### Métriques surveillées

- **Elasticsearch** : Santé du cluster, performance des requêtes
- **Logstash** : Débit de traitement, erreurs de parsing
- **Kibana** : Utilisation, sessions utilisateurs
- **Système** : CPU, mémoire, disque, réseau

### Commandes utiles

```bash
# Vérifier l'état des services
docker-compose ps

# Consulter les logs
docker-compose logs -f elasticsearch
docker-compose logs -f logstash
docker-compose logs -f kibana

# Statistiques Elasticsearch
curl -k -u elastic:password https://localhost:9200/_cluster/health?pretty

# État des index
curl -k -u elastic:password https://localhost:9200/_cat/indices?v

# Monitoring Logstash
curl http://localhost:9600/_node/stats?pretty
```

## 🔒 Sécurité

### Bonnes pratiques

1. **Mots de passe** : Utilisez des mots de passe forts et uniques
2. **Certificats** : Renouvelez régulièrement les certificats SSL
3. **Accès** : Limitez l'accès réseau aux ports nécessaires
4. **Sauvegardes** : Configurez des snapshots réguliers
5. **Mise à jour** : Maintenez la stack à jour

### Configuration firewall

```bash
# UFW (Ubuntu)
sudo ufw allow 5601/tcp  # Kibana
sudo ufw allow 9200/tcp  # Elasticsearch (si accès externe requis)
sudo ufw allow 5044/tcp  # Beats
sudo ufw allow 5045/tcp  # Wazuh
sudo ufw allow 5514/tcp  # Syslog
```

### Sauvegarde

```bash
# Snapshot Elasticsearch
curl -X PUT "https://localhost:9200/_snapshot/backup_repo" \
  -u elastic:password \
  -H "Content-Type: application/json" \
  -d '{
    "type": "fs",
    "settings": {
      "location": "/usr/share/elasticsearch/backup"
    }
  }'

# Créer un snapshot
curl -X PUT "https://localhost:9200/_snapshot/backup_repo/snapshot_$(date +%Y%m%d)" \
  -u elastic:password
```

## 🔧 Dépannage

### Problèmes courants

#### Elasticsearch ne démarre pas

```bash
# Vérifier les logs
docker-compose logs elasticsearch

# Problèmes de permissions
sudo chown -R 1000:1000 data/esdata

# Mémoire virtuelle insuffisante
sudo sysctl -w vm.max_map_count=262144
```

#### Logstash n'arrive pas à se connecter

```bash
# Vérifier la connectivité
docker-compose exec logstash curl -k https://elasticsearch:9200

# Vérifier les certificats
docker-compose exec logstash ls -la /usr/share/logstash/certs/
```

#### Kibana en erreur

```bash
# Vérifier l'état d'Elasticsearch
curl -k -u elastic:password https://localhost:9200/_cluster/health

# Réinitialiser l'index Kibana (ATTENTION: perte de configuration)
curl -X DELETE "https://localhost:9200/.kibana*" -u elastic:password
```

### Logs de débogage

```bash
# Activer le debug Logstash
# Dans logstash.yml
log.level: debug

# Activer le debug Elasticsearch
curl -X PUT "https://localhost:9200/_cluster/settings" \
  -u elastic:password \
  -H "Content-Type: application/json" \
  -d '{
    "transient": {
      "logger.discovery": "DEBUG"
    }
  }'
```

### Support et communauté

- **Documentation officielle** : https://www.elastic.co/guide/
- **Forums** : https://discuss.elastic.co/
- **GitHub** : https://github.com/elastic/
- **Discord** : Communauté Elastic FR

## 📝 Notes importantes

1. **Production** : Cette configuration est adaptée pour le développement et les tests. Pour la production, considérez :
   - Cluster multi-nœuds
   - Load balancer
   - Monitoring externe (Prometheus/Grafana)
   - Backup automatisé

2. **Performance** : Ajustez les paramètres selon votre environnement :
   - Heap size JVM
   - Nombre de shards/replicas
   - Refresh interval des index

3. **Conformité** : Vérifiez les exigences de conformité (RGPD, HIPAA, etc.) selon votre contexte.

---

🛡️ **Stack SIEM Elastic - Prêt pour la détection et la réponse aux incidents !**