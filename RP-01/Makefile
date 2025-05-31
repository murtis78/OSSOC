# Makefile pour NGiNX Proxy Manager
# Simplifie les opérations courantes

.PHONY: help install start stop restart status logs backup restore clean ssl-check ssl-gen update

# Configuration par défaut
COMPOSE_FILE := docker-compose.yml
PROJECT_NAME := nginx-proxy-manager
BACKUP_DIR := backups

# Couleurs pour l'affichage
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help: ## Affiche cette aide
	@echo "$(GREEN)NGiNX Proxy Manager - Commandes disponibles :$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

install: ## Installation complète (première fois)
	@echo "$(GREEN)Installation de NGiNX Proxy Manager...$(NC)"
	@chmod +x setup.sh
	@./setup.sh
	@echo "$(GREEN)Installation terminée !$(NC)"

start: ## Démarrer les services
	@echo "$(GREEN)Démarrage des services...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) up -d
	@sleep 5
	@make status

stop: ## Arrêter les services
	@echo "$(YELLOW)Arrêt des services...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) down

restart: ## Redémarrer les services
	@echo "$(YELLOW)Redémarrage des services...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) restart
	@sleep 5
	@make status

status: ## Afficher l'état des services
	@echo "$(GREEN)État des services :$(NC)"
	@docker-compose -f $(COMPOSE_FILE) ps
	@echo ""
	@echo "$(GREEN)Interface d'administration :$(NC)"
	@echo "http://$$(hostname -I | awk '{print $$1}'):81"

logs: ## Afficher les logs en temps réel
	@echo "$(GREEN)Logs en temps réel (Ctrl+C pour quitter) :$(NC)"
	@docker-compose -f $(COMPOSE_FILE) logs -f

logs-npm: ## Logs spécifiques à NPM
	@docker-compose -f $(COMPOSE_FILE) logs -f npm

logs-error: ## Logs d'erreur NGiNX
	@docker exec $(PROJECT_NAME) tail -f /var/log/nginx/error.log 2>/dev/null || echo "Container non trouvé"

logs-access: ## Logs d'accès NGiNX
	@docker exec $(PROJECT_NAME) tail -f /var/log/nginx/access.log 2>/dev/null || echo "Container non trouvé"

backup: ## Créer une sauvegarde
	@echo "$(GREEN)Création d'une sauvegarde...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@DATE=$$(date +%Y%m%d_%H%M%S) && \
	tar -czf $(BACKUP_DIR)/npm_backup_$$DATE.tar.gz data/ certs/ secrets/ configs/ .env && \
	echo "$(GREEN)Sauvegarde créée : $(BACKUP_DIR)/npm_backup_$$DATE.tar.gz$(NC)"

restore: ## Restaurer depuis une sauvegarde (make restore BACKUP=fichier.tar.gz)
	@if [ -z "$(BACKUP)" ]; then \
		echo "$(RED)Usage: make restore BACKUP=npm_backup_YYYYMMDD_HHMMSS.tar.gz$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Restauration depuis $(BACKUP)...$(NC)"
	@make stop
	@tar -xzf $(BACKUP_DIR)/$(BACKUP)
	@make start
	@echo "$(GREEN)Restauration terminée !$(NC)"

ssl-check: ## Vérifier les certificats SSL
	@echo "$(GREEN)Vérification des certificats SSL :$(NC)"
	@for cert in secrets/ssl/*.crt; do \
		if [ -f "$$cert" ]; then \
			echo "$(YELLOW)=== $$(basename $$cert) ===$(NC)"; \
			openssl x509 -in "$$cert" -noout -subject -dates; \
			echo ""; \
		fi; \
	done

ssl-gen: ## Générer un nouveau certificat SSL (make ssl-gen DOMAIN=example.com)
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Usage: make ssl-gen DOMAIN=example.com$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Génération du certificat SSL pour $(DOMAIN)...$(NC)"
	@openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout secrets/ssl/$(DOMAIN).key \
		-out secrets/ssl/$(DOMAIN).crt \
		-subj "/C=FR/ST=Ile-de-France/L=Paris/O=MyOrganization/CN=$(DOMAIN)"
	@chmod 600 secrets/ssl/$(DOMAIN).key
	@chmod 644 secrets/ssl/$(DOMAIN).crt
	@echo "$(GREEN)Certificat généré pour $(DOMAIN)$(NC)"

ssl-wildcard: ## Générer un certificat wildcard (make ssl-wildcard DOMAIN=example.com)
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Usage: make ssl-wildcard DOMAIN=example.com$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Génération du certificat wildcard pour *.$(DOMAIN)...$(NC)"
	@openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout secrets/ssl/wildcard-$(DOMAIN).key \
		-out secrets/ssl/wildcard-$(DOMAIN).crt \
		-subj "/C=FR/ST=Ile-de-France/L=Paris/O=MyOrganization/CN=*.$(DOMAIN)"
	@chmod 600 secrets/ssl/wildcard-$(DOMAIN).key
	@chmod 644 secrets/ssl/wildcard-$(DOMAIN).crt
	@echo "$(GREEN)Certificat wildcard généré pour *.$(DOMAIN)$(NC)"

update: ## Mettre à jour les images Docker
	@echo "$(GREEN)Mise à jour des images Docker...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) pull
	@docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)Mise à jour terminée !$(NC)"

clean: ## Nettoyer les ressources Docker inutilisées
	@echo "$(YELLOW)Nettoyage des ressources Docker...$(NC)"
	@docker system prune -f
	@docker volume prune -f
	@echo "$(GREEN)Nettoyage terminé !$(NC)"

clean-logs: ## Vider les logs
	@echo "$(YELLOW)Suppression des logs...$(NC)"
	@docker exec $(PROJECT_NAME) sh -c "truncate -s 0 /var/log/nginx/*.log" 2>/dev/null || true
	@echo "$(GREEN)Logs supprimés !$(NC)"

health: ## Vérifier la santé du service
	@echo "$(GREEN)Vérification de la santé du service :$(NC)"
	@curl -f http://localhost:81/api >/dev/null 2>&1 && \
		echo "$(GREEN)✓ Service opérationnel$(NC)" || \
		echo "$(RED)✗ Service non disponible$(NC)"

shell: ## Accéder au shell du container
	@echo "$(GREEN)Accès au shell du container...$(NC)"
	@docker exec -it $(PROJECT_NAME) /bin/bash

stats: ## Afficher les statistiques d'utilisation
	@echo "$(GREEN)Statistiques d'utilisation :$(NC)"
	@docker stats $(PROJECT_NAME) --no-stream

ports: ## Vérifier les ports utilisés
	@echo "$(GREEN)Ports utilisés par NPM :$(NC)"
	@docker port $(PROJECT_NAME) 2>/dev/null || echo "Container non trouvé"

config-test: ## Tester la configuration NGiNX
	@echo "$(GREEN)Test de la configuration NGiNX...$(NC)"
	@docker exec $(PROJECT_NAME) nginx -t 2>/dev/null || echo "Erreur de configuration"

reload: ## Recharger la configuration NGiNX
	@echo "$(GREEN)Rechargement de la configuration NGiNX...$(NC)"
	@docker exec $(PROJECT_NAME) nginx -s reload 2>/dev/null || echo "Erreur lors du rechargement"

env-check: ## Vérifier le fichier .env
	@echo "$(GREEN)Vérification du fichier .env :$(NC)"
	@if [ -f .env ]; then \
		echo "$(GREEN)✓ Fichier .env présent$(NC)"; \
		echo "Variables principales :"; \
		grep -E "^(NPM_INIT_EMAIL|LETSENCRYPT_EMAIL|DISABLE_IPV6)" .env | sed 's/^/  /'; \
	else \
		echo "$(RED)✗ Fichier .env manquant$(NC)"; \
	fi

quick-start: start ## Alias pour démarrage rapide

# Commande par défaut
.DEFAULT_GOAL := help
