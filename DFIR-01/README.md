# DFIR Stack - TheHive + Cortex + Shuffle + Redis

Une stack complète d'analyse et de réponse aux incidents de sécurité (DFIR) basée sur Docker, intégrant TheHive, Cortex, Shuffle et Redis.

## 🏗️ Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   TheHive   │◄──►│   Cortex    │◄──►│   Shuffle   │
│   :9000     │    │   :9001     │    │   :3001     │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                   ┌─────────────┐
                   │    Redis    │
                   │   :6379     │
                   └─────────────┘
```

## 🚀 Installation rapide

### Prérequis

- **Docker** >= 20.10
- **Docker Compose** >= 2.0
- **Git** (optionnel, pour les règles Yara)
- **OpenSSL** (pour la génération des certificats)

### Installation automatique

```bash
# Cloner ou télécharger les fichiers de configuration
git clone <votre-repo> dfir-stack
cd dfir-stack

# Exécuter le script d'installation
chmod +x setup.sh
./setup.sh

# Démarrer la stack
cd dfir-01/
./start.sh
```

### Installation manuelle

```bash
# Créer la structure de répertoires
mkdir -p dfir-01/{configs/{thehive,cortex,shuffle},data/{thehive,cortex,redis,shuffle},certs,secrets,modules}
cd dfir-01/

# Copier les fichiers de configuration
# (docker-compose.yml, .env, configs/*)

# Ajuster les permissions
sudo chown -R 1000:1000 data/ configs/
sudo chmod -R 755 data/

# Démarrer les services
docker-compose up -d
```

## 🎯 Services

| Service | Port | Description | Credentials par défaut |
|---------|------|-------------|------------------------|
| **TheHive** | 9000 | Gestion des cas et incidents | `admin@thehive.local` / `secret` |
| **Cortex** | 9001 | Analyseurs et enrichissement | `admin@cortex.local` / `secret` |
| **Shuffle** | 3001 | Orchestration et workflows | Configuration via API |
| **Redis** | 6379 | Base de données partagée | Authentification par mot de passe |

## 🔧 Configuration

### Variables d'environnement (.env)

Les secrets sont générés automatiquement par le script `setup.sh` :

```env
THEHIVE_SECRET=<généré-automatiquement>
CORTEX_SECRET=<généré-automatiquement>
REDIS_PASSWORD=<généré-automatiquement>
SHUFFLE_API_KEY=<généré-automatiquement>
CORTEX_API_KEY=<généré-automatiquement>
```

### Intégrations pré-configurées

#### TheHive ↔ Cortex
- Connexion API automatique via `CORTEX_API_KEY`
- Analyseurs disponibles dans l'interface TheHive
- Enrichissement automatique des observables

#### TheHive ↔ Shuffle
- Webhooks configurés pour les événements
- Workflows déclenchés automatiquement
- Actions sur les cas et alertes

#### Cortex ↔ Shuffle
- Exécution d'analyseurs via workflows
- Résultats intégrés dans les processus

## 🔍 Analyseurs Cortex pré-configurés

### Analyseurs de base (sans clé API)
- **File_Info** : Informations sur les fichiers
- **Yara** : Détection par signatures
- **Abuse_Finder** : Recherche de contacts abuse
- **MaxMind_GeoIP** : Géolocalisation IP

### Analyseurs avec clé API (à configurer)
- **VirusTotal** : Analyse antivirus
- **Shodan** : Reconnaissance réseau
- **URLVoid** : Réputation des URLs
- **OTX AlienVault** : Threat intelligence

### Configuration des clés API

Éditez `configs/cortex/application.conf` :

```hocon
analyzer.config {
  "VirusTotal_GetReport_3_0" {
    key = "VOTRE_CLE_VIRUSTOTAL"
  }
  
  "Shodan_DNSResolve_1_0" {
    key = "VOTRE_CLE_SHODAN"
  }
  
  "OTXQuery_2_0" {
    key = "VOTRE_CLE_OTX"
  }
}
```

## 🤖 Workflows Shuffle pré-configurés

### Case Triage Automation
```yaml
Déclencheur: Nouveau cas TheHive
Actions:
  1. Enrichir les observables (VirusTotal)
  2. Calculer la sévérité
  3. Assigner un analyste
```

### Alert Enrichment
```yaml
Déclencheur: Nouvelle alerte TheHive
Actions:
  1. Géolocalisation IP (MaxMind)
  2. Vérification réputation (OTX)
  3. Mise à jour de l'alerte
```

## 📋 Gestion quotidienne

### Démarrage et arrêt

```bash
# Démarrer tous les services
./start.sh

# Arrêter tous les services
./stop.sh

# Redémarrer un service spécifique
docker-compose restart thehive
```

### Monitoring et logs

```bash
# Statut des services
docker-compose ps

# Logs en temps réel
docker-compose logs -f

# Logs d'un service spécifique
docker-compose logs -f thehive
docker-compose logs -f cortex
docker-compose logs -f shuffle
```

### Sauvegarde

```bash
# Sauvegarde automatique
./backup.sh

# Sauvegarde manuelle
docker-compose down
tar -czf backup-$(date +%Y%m%d).tar.gz data/ configs/ .env
docker-compose up -d
```

## 🔐 Sécurité

### Certificats SSL
- Certificats auto-signés générés automatiquement
- Stockés dans `certs/`
- Pour la production : remplacer par des certificats valides

### Réseau Docker
- Réseau isolé `dfir-network` (172.20.0.0/16)
- Communication inter-services sécurisée
- Ports exposés uniquement si nécessaire

### Secrets et authentification
- Mots de passe générés aléatoirement
- Clés API sécurisées
- Authentification Redis obligatoire

## 🛠️ Personnalisation

### Ajouter un analyseur Cortex

1. Modifier `configs/cortex/application.conf`
2. Ajouter la configuration de l'analyseur
3. Redémarrer Cortex : `docker-compose restart cortex`

### Créer un workflow Shuffle

1. Accéder à Shuffle (http://localhost:3001)
2. Créer un nouveau workflow
3. Configurer les déclencheurs et actions
4. Tester et activer

### Modifier les ports

Éditez `.env` :
```env
THEHIVE_PORT=9000
CORTEX_PORT=9001
SHUFFLE_PORT=3001
```

## 🐛 Dépannage

### Services qui ne démarrent pas

```bash
# Vérifier les logs
docker-compose logs [service]

# Vérifier l'espace disque
df -h

# Vérifier les permissions
ls -la data/
```

### Problèmes de connexion

```bash
# Tester la connectivité Redis
docker-compose exec redis redis-cli -a $REDIS_PASSWORD ping

# Vérifier les certificats
openssl x509 -in certs/server.crt -text -noout

# Tester les APIs
curl -k https://localhost:9000/api/status
curl -k https://localhost:9001/api/status
```

### Reset complet

```bash
# Arrêter et supprimer tout
docker-compose down -v
sudo rm -rf data/*

# Redémarrer
docker-compose up -d
```

## 📚 Documentation

### Liens officiels
- [TheHive Documentation](https://docs.thehive-project.org/)
- [Cortex Documentation](https://github.com/TheHive-Project/Cortex)
- [Shuffle Documentation](https://shuffler.io/docs/)

### Tutoriels recommandés
- [TheHive + Cortex Integration](https://blog.thehive-project.org/)
- [Shuffle Workflow Creation](https://shuffler.io/docs/workflows)
- [DFIR Best Practices](https://www.sans.org/white-papers/)

## 🤝 Support

### Logs utiles pour le support

```bash
# Collecter tous les logs
docker-compose logs > dfir-logs.txt

# Informations système
docker system info > system-info.txt
docker-compose config > compose-config.txt
```

### Problèmes fréquents

1. **Port déjà utilisé** : Modifier les ports dans `.env`
2. **Permissions insuffisantes** : `sudo chown -R 1000:1000 data/`
3. **Mémoire insuffisante** : Augmenter la RAM Docker ou réduire les services
4. **Certificats expirés** : Régénérer avec `openssl` dans `certs/`

## 📄 Licence

Cette configuration est fournie sous licence MIT. Les logiciels inclus conservent leurs licences respectives :
- TheHive : AGPL-3.0
- Cortex : AGPL-3.0  
- Shuffle : AGPL-3.0
- Redis : BSD

## 🔄 Mise à jour

```bash
# Sauvegarder avant mise à jour
./backup.sh

# Mettre à jour les images
docker-compose pull

# Redémarrer avec les nouvelles images
docker-compose up -d

# Vérifier que tout fonctionne
docker-compose ps
```

---

**Version** : 1.0  
**Dernière mise à jour** : $(date)  
**Compatibilité** : TheHive 5.1, Cortex 3.1.10, Shuffle 1.1.0, Redis 7.2