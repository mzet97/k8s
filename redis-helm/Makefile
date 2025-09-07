# Makefile para Redis Helm
# Facilita o gerenciamento do Redis com comandos simples

.PHONY: help install test status logs clean remove upgrade backup restore

# Variáveis
NAMESPACE := redis
RELEASE_NAME := redis-cluster
CHART_NAME := bitnami/redis
VALUES_FILE := values.yaml
HPA_FILE := hpa-config.yaml
MICROK8S := microk8s

# Comando padrão
help: ## Mostra esta ajuda
	@echo "Redis Helm - Comandos Disponíveis:"
	@echo "================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Instalação
install: ## Instala o Redis com Helm
	@echo "🚀 Instalando Redis com Helm via MicroK8s..."
	@./install-redis-helm.sh

install-manual: ## Instalação manual passo a passo
	@echo "📦 Adicionando repositório Bitnami..."
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo update
	@echo "🏗️ Criando namespace..."
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "🚀 Instalando Redis..."
	helm upgrade --install $(RELEASE_NAME) $(CHART_NAME) \
		--namespace $(NAMESPACE) \
		--values $(VALUES_FILE) \
		--wait --timeout=600s
	@echo "📈 Aplicando HPA..."
	kubectl apply -f $(HPA_FILE)
	@echo "✅ Instalação concluída!"

# Testes
test: ## Executa testes completos
	@echo "🧪 Executando testes..."
	@./test-redis-helm.sh

test-connection: ## Testa apenas conectividade
	@echo "🔗 Testando conectividade..."
	@kubectl run redis-test --rm -i --restart=Never --namespace $(NAMESPACE) \
		--image docker.io/bitnami/redis:7.2.4-debian-11-r0 --command -- bash -c \
		"REDISCLI_AUTH=$$(kubectl get secret $(RELEASE_NAME) -n $(NAMESPACE) -o jsonpath='{.data.redis-password}' | base64 -d) && \
		redis-cli -h $(RELEASE_NAME)-master.$(NAMESPACE).svc.cluster.local -p 6379 --tls --insecure ping"

# Status e monitoramento
status: ## Mostra status completo
	@echo "📊 Status do Redis Helm"
	@echo "======================"
	@echo "📦 Release Helm:"
	$(MICROK8S) helm3 list -n $(NAMESPACE)
	@echo ""
	@echo "🏃 Pods:"
	$(MICROK8S) kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo "🌐 Services:"
	$(MICROK8S) kubectl get svc -n $(NAMESPACE)
	@echo ""
	@echo "💾 PVCs:"
	$(MICROK8S) kubectl get pvc -n $(NAMESPACE)
	@echo ""
	@echo "📈 HPA:"
	$(MICROK8S) kubectl get hpa -n $(NAMESPACE)
	@echo ""
	@echo "🔐 Secrets:"
	$(MICROK8S) kubectl get secrets -n $(NAMESPACE)

info: ## Mostra informações de conexão
	@echo "📋 Informações de Conexão"
	@echo "========================"
	@echo "🔑 Senha do Redis:"
	@kubectl get secret $(RELEASE_NAME) -n $(NAMESPACE) -o jsonpath='{.data.redis-password}' | base64 -d
	@echo ""
	@echo ""
	@echo "🔗 Endpoints:"
	@echo "   Master: $(RELEASE_NAME)-master.$(NAMESPACE).svc.cluster.local:6379"
	@echo "   Replicas: $(RELEASE_NAME)-replica.$(NAMESPACE).svc.cluster.local:6379"
	@echo "   Métricas: $(RELEASE_NAME)-metrics.$(NAMESPACE).svc.cluster.local:9121"

password: ## Mostra apenas a senha do Redis
	@$(MICROK8S) kubectl get secret $(RELEASE_NAME) -n $(NAMESPACE) -o jsonpath='{.data.redis-password}' | base64 -d

# Logs
logs: ## Mostra logs de todos os pods
	@echo "📜 Logs do Redis"
	@echo "==============="
	@echo "📊 Master:"
	$(MICROK8S) kubectl logs -f $(RELEASE_NAME)-master-0 -n $(NAMESPACE) --tail=50

logs-master: ## Logs apenas do master
	kubectl logs -f $(RELEASE_NAME)-master-0 -n $(NAMESPACE)

logs-replica: ## Logs das replicas
	@echo "📊 Replica 0:"
	kubectl logs $(RELEASE_NAME)-replica-0 -n $(NAMESPACE) --tail=20
	@echo "📊 Replica 1:"
	kubectl logs $(RELEASE_NAME)-replica-1 -n $(NAMESPACE) --tail=20
	@echo "📊 Replica 2:"
	kubectl logs $(RELEASE_NAME)-replica-2 -n $(NAMESPACE) --tail=20

logs-metrics: ## Logs do redis-exporter
	kubectl logs -l app.kubernetes.io/component=metrics -n $(NAMESPACE)

# Gerenciamento
upgrade: ## Atualiza o Redis com novas configurações
	@echo "⬆️ Atualizando Redis..."
	$(MICROK8S) helm3 upgrade $(RELEASE_NAME) $(CHART_NAME) \
		--namespace $(NAMESPACE) \
		--values $(VALUES_FILE) \
		--wait
	@echo "✅ Atualização concluída!"

rollback: ## Faz rollback para versão anterior
	@echo "⏪ Fazendo rollback..."
	helm rollback $(RELEASE_NAME) -n $(NAMESPACE)
	@echo "✅ Rollback concluído!"

history: ## Mostra histórico de releases
	helm history $(RELEASE_NAME) -n $(NAMESPACE)

values: ## Mostra valores atuais do Helm
	helm get values $(RELEASE_NAME) -n $(NAMESPACE)

# Backup e Restore
backup: ## Cria backup do Redis
	@echo "💾 Criando backup..."
	@mkdir -p backups
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S) && \
	$(MICROK8S) kubectl exec $(RELEASE_NAME)-master-0 -n $(NAMESPACE) -- \
		redis-cli --rdb /tmp/backup_$$TIMESTAMP.rdb && \
	$(MICROK8S) kubectl cp $(RELEASE_NAME)-master-0:/tmp/backup_$$TIMESTAMP.rdb \
		./backups/backup_$$TIMESTAMP.rdb -n $(NAMESPACE) && \
	echo "✅ Backup criado: backups/backup_$$TIMESTAMP.rdb"

list-backups: ## Lista backups disponíveis
	@echo "📁 Backups disponíveis:"
	@ls -la backups/ 2>/dev/null || echo "Nenhum backup encontrado"

# Conectividade
connect: ## Conecta ao Redis Master via CLI
	@echo "🔗 Conectando ao Redis Master..."
	$(MICROK8S) kubectl run redis-client --rm -it --restart=Never --namespace $(NAMESPACE) \
		--image docker.io/bitnami/redis:7.2.4-debian-11-r0 -- bash -c \
		"REDISCLI_AUTH=$$($(MICROK8S) kubectl get secret $(RELEASE_NAME) -n $(NAMESPACE) -o jsonpath='{.data.redis-password}' | base64 -d) && \
		redis-cli -h $(RELEASE_NAME)-master.$(NAMESPACE).svc.cluster.local -p 6379 --tls --insecure"

connect-replica: ## Conecta a uma replica via CLI
	@echo "🔗 Conectando ao Redis Replica..."
	kubectl run redis-client-replica --rm -it --restart=Never --namespace $(NAMESPACE) \
		--image docker.io/bitnami/redis:7.2.4-debian-11-r0 -- bash -c \
		"REDISCLI_AUTH=$$(kubectl get secret $(RELEASE_NAME) -n $(NAMESPACE) -o jsonpath='{.data.redis-password}' | base64 -d) && \
		redis-cli -h $(RELEASE_NAME)-replica.$(NAMESPACE).svc.cluster.local -p 6379 --tls --insecure"

# Métricas
metrics: ## Acessa métricas via port-forward
	@echo "📊 Acessando métricas (Ctrl+C para sair)..."
	@echo "URL: http://localhost:9121/metrics"
	$(MICROK8S) kubectl port-forward svc/$(RELEASE_NAME)-metrics 9121:9121 -n $(NAMESPACE)

metrics-curl: ## Mostra métricas via curl
	@kubectl run metrics-test --rm -i --restart=Never --namespace $(NAMESPACE) \
		--image curlimages/curl:latest --command -- \
		curl -s http://$(RELEASE_NAME)-metrics.$(NAMESPACE).svc.cluster.local:9121/metrics | head -20

# Limpeza
clean: ## Remove recursos temporários
	@echo "🧹 Limpando recursos temporários..."
	kubectl delete pod -l "run in (redis-client,redis-test,metrics-test)" -n $(NAMESPACE) --ignore-not-found=true
	@echo "✅ Limpeza concluída!"

remove: ## Remove completamente o Redis
	@echo "🗑️ Removendo Redis..."
	@./remove-redis-helm.sh

remove-force: ## Remove forçadamente (sem confirmação)
	@echo "🗑️ Removendo Redis (força)..."
	helm uninstall $(RELEASE_NAME) -n $(NAMESPACE) || true
	kubectl delete pvc --all -n $(NAMESPACE) --ignore-not-found=true
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "✅ Remoção forçada concluída!"

# Debug
debug: ## Informações de debug
	@echo "🐛 Informações de Debug"
	@echo "======================"
	@echo "📦 Helm Release:"
	$(MICROK8S) helm3 status $(RELEASE_NAME) -n $(NAMESPACE)
	@echo ""
	@echo "🔍 Describe Pods:"
	$(MICROK8S) kubectl describe pods -l app.kubernetes.io/name=redis -n $(NAMESPACE)
	@echo ""
	@echo "🔍 Events:"
	$(MICROK8S) kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

debug-master: ## Debug específico do master
	kubectl describe pod $(RELEASE_NAME)-master-0 -n $(NAMESPACE)

debug-replica: ## Debug específico das replicas
	kubectl describe pod $(RELEASE_NAME)-replica-0 -n $(NAMESPACE)

# Utilitários
shell-master: ## Shell no pod master
	kubectl exec -it $(RELEASE_NAME)-master-0 -n $(NAMESPACE) -- bash

shell-replica: ## Shell no pod replica
	kubectl exec -it $(RELEASE_NAME)-replica-0 -n $(NAMESPACE) -- bash

top: ## Mostra uso de recursos dos pods
	kubectl top pods -n $(NAMESPACE)

watch: ## Monitora pods em tempo real
	watch kubectl get pods -n $(NAMESPACE)

# Validação
validate: ## Valida configuração antes da instalação
	@echo "✅ Validando configuração..."
	helm template $(RELEASE_NAME) $(CHART_NAME) --values $(VALUES_FILE) --dry-run > /dev/null
	@echo "✅ Configuração válida!"

lint: ## Verifica sintaxe dos arquivos
	@echo "🔍 Verificando sintaxe..."
	helm lint . || echo "⚠️ Lint não aplicável (não é um chart)"
	yamllint $(VALUES_FILE) $(HPA_FILE) || echo "⚠️ yamllint não instalado"
	@echo "✅ Verificação concluída!"