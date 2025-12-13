#!/bin/bash

# Script de Instalação do Redis Master-Replica no Kubernetes
# Baseado na documentação do README.md
# Executa os comandos na ordem correta para instalação completa

set -e  # Parar execução em caso de erro

echo "🚀 Iniciando instalação do Redis Master-Replica no Kubernetes..."
echo ""

# Selecionar cliente Kubernetes (preferir kubectl se estiver funcional)
KUBECTL_BIN="${KUBECTL_BIN:-}"
if [ -z "$KUBECTL_BIN" ]; then
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
            KUBECTL_BIN="kubectl"
        fi
    fi
fi
if [ -z "$KUBECTL_BIN" ] && command -v microk8s >/dev/null 2>&1; then
    KUBECTL_BIN="microk8s kubectl"
fi
if [ -z "$KUBECTL_BIN" ]; then
    echo "❌ Erro: nem 'kubectl' nem 'microk8s kubectl' encontrados/funcionais."
    echo "Instale/configure 'kubectl' ou MicroK8s e recarregue as permissões (newgrp microk8s)."
    exit 1
fi
echo "ℹ️ Usando cliente Kubernetes: $KUBECTL_BIN"

echo "📋 Pré-requisitos verificados"
echo ""

# 1. Criar namespace e configurações básicas
echo "1️⃣ Criando namespace e configurações básicas..."
$KUBECTL_BIN apply -f 00-namespace.yaml
$KUBECTL_BIN apply -f 01-secret.yaml
$KUBECTL_BIN apply -f 03-rbac.yaml
echo "✅ Namespace e configurações básicas criadas"
echo ""

# 2. Configurar TLS e certificados
echo "2️⃣ Configurando TLS e certificados..."
$KUBECTL_BIN apply -f 02-tls-certificates.yaml
echo "✅ Certificados TLS configurados"
echo ""

# Aguardar certificados serem criados
echo "⏳ Aguardando certificados TLS serem criados..."
echo "Verificando se o secret redis-tls-secret foi criado..."

# Aguardar até 120 segundos pelos certificados
for i in {1..24}; do
    if $KUBECTL_BIN get secret redis-tls-secret -n redis >/dev/null 2>&1; then
        echo "✅ Secret redis-tls-secret criado com sucesso!"
        break
    fi
    echo "Tentativa $i/24: Aguardando secret redis-tls-secret..."
    sleep 5
done

# Verificar se o secret foi criado
if ! $KUBECTL_BIN get secret redis-tls-secret -n redis >/dev/null 2>&1; then
    echo "❌ Erro: Secret redis-tls-secret não foi criado após 120 segundos"
    echo "Verifique os logs do cert-manager:"
    echo "$KUBECTL_BIN logs -n cert-manager -l app=cert-manager"
    exit 1
fi

$KUBECTL_BIN -n redis get certificates
echo ""

# 3. Configurar Redis (ConfigMaps e Services)
echo "3️⃣ Configurando Redis (ConfigMaps e Services)..."
$KUBECTL_BIN apply -f 10-configmap.yaml
$KUBECTL_BIN apply -f 11-headless-svc.yaml
$KUBECTL_BIN apply -f 12-client-svc.yaml
$KUBECTL_BIN apply -f 13-master-svc.yaml
echo "✅ ConfigMaps e Services configurados"
echo ""

# 4. Implantar Redis Master e Réplicas
echo "4️⃣ Implantando Redis Master e Réplicas..."
$KUBECTL_BIN apply -f 21-master-statefulset.yaml
$KUBECTL_BIN apply -f 22-replica-statefulset.yaml
echo "✅ Redis Master e Réplicas implantados"
echo ""

# Aguardar pods estarem prontos
echo "⏳ Aguardando pods Redis estarem prontos..."
echo "Verificando se os pods Redis Master e Replica estão funcionando..."

# Aguardar até 180 segundos pelos pods
for i in {1..36}; do
    READY_PODS=$($KUBECTL_BIN get pods -n redis -l 'app in (redis-master,redis-replica)' --no-headers 2>/dev/null | grep -c "Running" 2>/dev/null || echo "0")
    TOTAL_PODS=$($KUBECTL_BIN get pods -n redis -l 'app in (redis-master,redis-replica)' --no-headers 2>/dev/null | wc -l 2>/dev/null || echo "0")
    
    # Remover quebras de linha e espaços extras
    READY_PODS=$(echo "$READY_PODS" | tr -d '\n\r' | xargs)
    TOTAL_PODS=$(echo "$TOTAL_PODS" | tr -d '\n\r' | xargs)
    
    # Verificar se são números válidos
    if ! [[ "$READY_PODS" =~ ^[0-9]+$ ]]; then
        READY_PODS=0
    fi
    if ! [[ "$TOTAL_PODS" =~ ^[0-9]+$ ]]; then
        TOTAL_PODS=0
    fi
    
    if [ "$READY_PODS" -gt 0 ] && [ "$READY_PODS" -eq "$TOTAL_PODS" ]; then
        echo "✅ Todos os pods Redis estão funcionando ($READY_PODS/$TOTAL_PODS)!"
        break
    fi
    echo "Tentativa $i/36: Pods prontos: $READY_PODS/$TOTAL_PODS"
    sleep 5
done

$KUBECTL_BIN -n redis get pods
echo ""

# 5. Configurar replicação
echo "5️⃣ Configurando replicação..."
$KUBECTL_BIN apply -f 31-replication-setup-job.yaml
echo "✅ Replicação configurada"
echo ""

# 6. Instalar metrics-server (necessário para HPA)
echo "6️⃣ Instalando metrics-server..."
microk8s enable metrics-server || true
echo "✅ Metrics-server instalado"
echo ""

# 7. Configurar acesso externo
echo "7️⃣ Configurando acesso externo..."
$KUBECTL_BIN apply -f 43-dns-config.yaml
echo "✅ Acesso externo configurado"
echo ""

# 8. Configurar monitoramento e backup (opcional)
echo "8️⃣ Configurando monitoramento e backup (opcional)..."
$KUBECTL_BIN apply -f 50-backup-cronjob.yaml
# microk8s kubectl apply -f 60-monitoring.yaml  # Temporariamente desativado
$KUBECTL_BIN apply -f 70-high-availability.yaml
echo "✅ Monitoramento e backup configurados"
echo ""

# Verificação da instalação
echo "🔍 Verificando instalação..."
echo ""

echo "📊 Status dos pods:"
$KUBECTL_BIN -n redis get pods
echo ""

echo "🌐 Serviços disponíveis:"
$KUBECTL_BIN -n redis get svc
echo ""

echo "🔐 Certificados TLS:"
$KUBECTL_BIN -n redis get certificates
echo ""

# Obter IP do nó para configuração DNS
NODE_IP=$($KUBECTL_BIN get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "📡 IP do nó Kubernetes: $NODE_IP"
echo ""

echo "🎉 Instalação concluída com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo "1. Configure o DNS local adicionando ao arquivo hosts:"
echo "   $NODE_IP redis.home.arpa"
echo "   $NODE_IP redis-proxy.home.arpa"
echo ""
echo "2. Teste a conectividade:"
echo "   redis-cli -h redis.home.arpa -p 30380 -a Admin@123 ping"
echo ""
echo "3. Acesse o dashboard HAProxy:"
echo "   http://redis.home.arpa:30404/stats (admin/admin123)"
echo ""
echo "📚 Consulte o README.md para mais informações sobre testes e uso."