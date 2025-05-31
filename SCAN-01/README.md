# Vulnerability Scanning Environment

Infrastructure complète de scan de vulnérabilités avec OpenVAS, VulnWhisperer et Nmap.

## 📋 Composants

- **OpenVAS 22.4** - Scanner de vulnérabilités principal
- **VulnWhisperer** - Agrégateur et exportateur de données vers Elasticsearch
- **Nmap** - Scanner de réseau et de ports personnalisé
- **Redis** - Cache et stockage temporaire
- **Scheduler** - Planificateur de scans automatisés

## 🚀 Démarrage rapide

### 1. Prérequis

- Docker et Docker Compose installés
- Au moins 4GB de RAM disponible
- 10GB d'espace disque libre

### 2. Installation

```bash
# Cloner et configurer
git clone <repository>
cd scan-01/

# Exécuter le script de setup
chmod +x setup.sh
./setup.sh

# Personnaliser les configurations
nano .env
nano configs/openvas/openvas.conf
nano configs/vulnwhisperer/config.ini
```

### 3. Démarrage des services

```bash
# Démarrer tous les services
docker-compose up -d

# Vérifier le statut
docker-compose ps

# Voir les logs
docker-compose logs -f openvas
```

### 4. Accès aux services

- **OpenVAS Web UI**: http://localhost:9392
  - Utilisateur: `admin`
  - Mot de passe: Défini dans `.env` (OPENVAS_ADMIN_PWD)

## 📁 Structure des fichiers

```
scan-01/
├── docker-compose.yml          # Orchestration des conteneurs
├── .env                        # Variables d'environnement
├── setup.sh                   # Script d'installation
├── configs/                   # Configurations
│   ├── openvas/
│   │   └── openvas.conf       # Config OpenVAS
│   ├── vulnwhisperer/
│   │   └── config.ini         # Config VulnWhisperer
│   └── nmap/
│       └── nmap.conf          # Config Nmap
├── data/                      # Données persistantes
│   ├── openvas/              # Base de données OpenVAS
│   ├── vulnwhisperer/        # Données VulnWhisperer
│   ├── nmap-reports/         # Rapports Nmap
│   │   ├── xml/
│   │   ├── json/
│   │   └── html/
│   └── redis/                # Cache Redis
├── modules/                   # Scripts et modules
│   ├── nmap/
│   │   ├── Dockerfile
│   │   └── scripts/
│   ├── scheduler/
│   └── health-check.sh
├── certs/                     # Certificats SSL
└── secrets/                   # Secrets et clés
```

## ⚙️ Configuration

### Variables d'environnement (.env)

```bash
# OpenVAS
OPENVAS_ADMIN_PWD=VotreMotDePasse!
OPENVAS_WEB_PORT=9392

# VulnWhisperer
VULNWHISPERER_ELASTIC=http://siem-01:9200
VULNWHISPERER_SYNC_INTERVAL=3600

# Scanning
SCAN_INTERVAL=21600
DEFAULT_SCAN_TARGETS=192.168.1.0/24,10.0.0.0/8
MAX_CONCURRENT_SCANS=3
```

### Cibles de scan

Modifiez `data/nmap-reports/targets.txt` pour définir vos cibles :

```
# Exemples de cibles
192.168.1.0/24
10.0.0.1-10.0.0.100
scanme.nmap.org
```

## 🔄 Utilisation

### Scans automatisés

Les scans sont programmés automatiquement selon `SCAN_INTERVAL` :

- OpenVAS : Scans de vulnérabilités complets
- Nmap : Scans de découverte et de ports
- VulnWhisperer : Synchronisation vers Elasticsearch

### Scans manuels

```bash
# Scan Nmap manuel
docker exec nmap-scanner nmap -sS -O 192.168.1.0/24 -oX /reports/manual_scan.xml

# Conversion XML vers JSON
docker exec nmap-scanner python3 /scripts/xml_to_json.py \
    /reports/manual_scan.xml /reports/manual_scan.json
```

### Monitoring

```bash
# Vérifier la santé des services
./modules/health-check.sh

# Logs en temps réel
docker-compose logs -f

# Statistiques des conteneurs
docker stats
```

## 📊 Pipeline de données

```
[Nmap Scanner] ──────┐
                     │
[OpenVAS Scanner] ────┼──→ [VulnWhisperer] ──→ [Elasticsearch]
                     │                              │
[Autres scanners] ────┘                              │
                                                     ▼
                                            [SIEM/Kibana]
```

### Formats de sortie

- **XML** : Rapports bruts des scanners
- **JSON** : Format structuré pour analyse
- **HTML** : Rapports visuels
- **Elasticsearch** : Indexation pour recherche et visualisation

## 🛠️ Maintenance

### Sauvegardes

```bash
# Sauvegarder les données
docker-compose exec openvas tar -czf /tmp/openvas-backup.tar.gz /var/lib/openvas/
docker cp openvas:/tmp/openvas-backup.tar.gz ./backups/

# Sauvegarder les rapports
tar -czf backups/reports-$(date +%Y%m%d).tar.gz data/nmap-reports/
```

### Mise à jour des feeds

```bash
# Mise à jour manuelle des feeds OpenVAS
docker-compose exec openvas greenbone-feed-sync --type SCAP
docker-compose exec openvas greenbone-feed-sync --type CERT
docker-compose exec openvas greenbone-feed-sync --type GVMD_DATA
```

### Nettoyage

```bash
# Nettoyer les anciens rapports (garde les 30 derniers jours)
find data/nmap-reports/xml/ -name "*.xml" -mtime +30 -delete
find data/nmap-reports/json/ -name "*.json" -mtime +30 -delete

# Nettoyer les logs Docker
docker system prune -f
```

## 🔒 Sécurité

### Recommandations

- Changez tous les mots de passe par défaut
- Utilisez HTTPS en production
- Configurez un pare-feu approprié
- Limitez l'accès réseau aux services
- Activez les logs d'audit

### Ports exposés

- `9392` : OpenVAS Web Interface
- `9390` : OpenVAS GMP Protocol (interne)

## 🚨 Dépannage

### Problèmes courants

**OpenVAS ne démarre pas :**
```bash
# Vérifier les logs
docker-compose logs openvas

# Vérifier l'espace disque
df -h

# Reconstruire le conteneur
docker-compose down
docker-compose up --build openvas
```

**VulnWhisperer ne synchronise pas :**
```bash
# Vérifier la connectivité Elasticsearch
docker-compose exec vulnwhisperer curl -I http://siem-01:9200

# Vérifier la configuration
docker-compose exec vulnwhisperer cat /app/config.ini
```

**Nmap n'arrive pas à scanner :**
```bash
# Vérifier les permissions réseau
docker-compose exec nmap-scanner nmap --privileged 127.0.0.1

# Vérifier les cibles
cat data/nmap-reports/targets.txt
```

### Logs utiles

```bash
# Logs de tous les services
docker-compose logs

# Logs spécifiques
docker-compose logs openvas
docker-compose logs vulnwhisperer
docker-compose logs nmap-scanner

# Logs avec timestamps
docker-compose logs -t --since="1h"
```

## 📈 Performance

### Optimisation

- Ajustez `MAX_CONCURRENT_SCANS` selon vos ressources
- Configurez `SCAN_INTERVAL` selon vos besoins
- Utilisez des cibles de scan spécifiques plutôt que des plages larges
- Configurez Redis pour la persistance des données temporaires

### Monitoring des ressources

```bash
# Utilisation CPU/Mémoire
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Espace disque utilisé
du -sh data/
```

## 🤝 Support

Pour des questions ou problèmes :

1. Vérifiez les logs : `docker-compose logs`
2. Consultez la documentation OpenVAS
3. Vérifiez la configuration VulnWhisperer
4. Testez la connectivité réseau

## 📝 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.