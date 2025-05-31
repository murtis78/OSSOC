# DFIR-02 Stack – IRIS + Velociraptor

Une stack moderne et automatisée de **Digital Forensics & Incident Response** (DFIR) avec [IRIS](https://dfir-iris.org/) et [Velociraptor](https://www.velocidex.com/), déployée via Docker Compose.
Cette stack intègre aussi PostgreSQL, Redis, gestion automatisée des secrets, certificats SSL, scripts d’initialisation, et permet une exploitation rapide pour le SOC ou le pentest.

---

## 🏗️ Architecture

```
┌───────────┐        ┌─────────────┐
│   IRIS    │◄──────►│ PostgreSQL  │
│  :8080    │        │   :5432     │
│           │        └─────────────┘
│           │
│           │        ┌─────────────┐
│           │───────►│   Redis     │
│           │        │   :6379     │
└───────────┘        └─────────────┘
     │
     │
     ▼
┌──────────────┐
│ Velociraptor │
│   :8889      │ (GUI)
│   :8001      │ (API)
└──────────────┘
```

---

## 🚀 Installation rapide

### Prérequis

* **Docker** >= 20.10
* **Docker Compose** >= 2.0
* **OpenSSL** (pour les certificats)
* **Git** (optionnel, pour cloner le repo)

### Installation automatique

```bash
# Cloner le dépôt
git clone <votre-repo> dfir-02
cd dfir-02

# Rendre le script exécutable
chmod +x startup.sh

# Démarrer l’installation
./startup.sh start
```

### Commandes principales

```bash
./startup.sh start    # Démarrer la stack
./startup.sh stop     # Stopper tous les services
./startup.sh restart  # Redémarrer la stack
./startup.sh status   # Voir le statut des services
./startup.sh logs     # Voir les logs
./startup.sh update   # Mettre à jour les images Docker
```

---

## 🎯 Services et ports

| Service          | Port                       | Description                | Identifiants par défaut                       |
| ---------------- | -------------------------- | -------------------------- | --------------------------------------------- |
| **IRIS**         | 8080                       | Gestion de l’investigation | admin / (voir secrets/iris\_admin\_password)  |
| **Velociraptor** | 8889 (GUI) <br> 8001 (API) | Endpoint Forensics & Hunt  | admin / (voir secrets/velociraptor\_password) |
| **PostgreSQL**   | 5432                       | Base de données            | iris / (voir secrets/postgres\_password)      |
| **Redis**        | 6379                       | Cache & files IRIS         | (voir secrets/redis\_password)                |

*Les mots de passe sont générés et stockés dans le dossier `secrets/` au premier lancement.*

---

## 🔧 Configuration

### Variables d’environnement (.env)

Toutes les principales variables sont stockées dans `.env` :

* Ports
* Credentials par défaut
* SSL/certificats
* Timezone
* Réseau Docker

Exemple de variables importantes :

```env
IRIS_ADMIN_USER=admin
IRIS_ADMIN_PASSWORD=...
POSTGRES_USER=iris
POSTGRES_PASSWORD=...
REDIS_PASSWORD=...
VELOCIRAPTOR_USER=admin
VELOCIRAPTOR_PASSWORD=...
TZ=Europe/Paris
NETWORK_SUBNET=172.20.0.0/16
```

---

## 📦 Structure du projet

```
.
├── .env
├── docker-compose.yml
├── startup.sh
├── certs/
├── configs/
│   ├── iris/
│   ├── postgres/
│   └── velociraptor/
├── data/
├── modules/
│   ├── generate-certs.sh
│   ├── install-iris-velociraptor-module.sh
│   └── startup.sh
├── secrets/
└── logs/
```

---

## 🛠️ Personnalisation et initialisation

* **Certificats SSL** : générés automatiquement par le script `generate-certs.sh` (modifiables dans `certs/`).
* **Secrets** : tous les mots de passe générés sont stockés dans `secrets/`.
* **Init SQL** : la base PostgreSQL est initialisée via `init.sql` si besoin.
* **Configs avancées** : modifiez les fichiers dans `configs/iris`, `configs/velociraptor`, etc.

---

## 📋 Gestion quotidienne

### Démarrage et arrêt

```bash
./startup.sh start   # Démarrer tous les services
./startup.sh stop    # Stopper la stack
```

### Logs et monitoring

```bash
./startup.sh logs
docker-compose logs -f
docker-compose logs -f iris
docker-compose logs -f velociraptor
```

### Sauvegarde

```bash
docker-compose down
tar -czf backup-$(date +%Y%m%d).tar.gz data/ configs/ .env secrets/
```

---

## 🔐 Sécurité

* **Mots de passe uniques** : générés pour chaque service, stockés dans `secrets/`.
* **Certificats auto-signés** : à remplacer par vos propres certificats pour la production.
* **Réseau Docker isolé** : communication sécurisée entre les containers.
* **Accès** : seuls les ports nécessaires sont exposés.

---

## 🐛 Dépannage

### Problèmes fréquents

1. **Service qui ne démarre pas** :

   * Vérifiez les logs `./startup.sh logs` ou `docker-compose logs`.
   * Vérifiez l’espace disque et les permissions sur `data/` et `configs/`.

2. **Port déjà utilisé** :

   * Modifiez les ports dans `.env`.

3. **Accès refusé ou erreurs d’authentification** :

   * Consultez le dossier `secrets/` pour les mots de passe générés.

4. **Certificats SSL non valides** :

   * Régénérez-les ou utilisez vos propres certificats dans `certs/`.

---

## 📚 Documentation

* [Documentation IRIS](https://docs.dfir-iris.org/)
* [Documentation Velociraptor](https://docs.velociraptor.app/)

---

## 🤝 Support

Pour toute question, ouvrez une issue sur le dépôt GitHub ou contactez la communauté des projets utilisés.

---

## 📄 Licence

Ce projet est publié sous licence MIT. Les logiciels inclus gardent leurs licences :

* IRIS : AGPL-3.0
* Velociraptor : Apache-2.0
* PostgreSQL : PostgreSQL License
* Redis : BSD

---

**Version** : 1.0
**Dernière mise à jour** : \$(date)
**Compatibilité** : IRIS 2.x, Velociraptor 0.7+, PostgreSQL 15+, Redis 7+

---