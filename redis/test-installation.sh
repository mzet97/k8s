#!/bin/bash

# Script para testar a instalação do Redis após correções

echo "🧪 Testando instalação do Redis..."
echo ""

# Verificar se o namespace existe
echo "📋 Verificando namespace..."
if microk8s kubectl get namespace redis >/dev/null 2>&1; then
    echo "✅ Namespace redis existe"
else
    echo "❌ Namespace redis não encontrado"
    exit 1
fi
echo ""

# Verificar certificados TLS
echo "🔐 Verificando certificados TLS..."
if microk8s kubectl get secret redis-tls-secret -n redis >/dev/null 2>&1; then
    echo "✅ Secret redis-tls-secret existe"
    microk8s kubectl -n redis get certificates
else
    echo "❌ Secret redis-tls-secret não encontrado"
fi
echo ""

# Verificar pods
echo "🚀 Verificando status dos pods..."
READY_PODS=$(microk8s kubectl get pods -n redis -l 'app in (redis-master,redis-replica)' --no-headers 2>/dev/null | grep -c "Running" 2>/dev/null || echo "0")
TOTAL_PODS=$(microk8s kubectl get pods -n redis -l 'app in (redis-master,redis-replica)' --no-headers 2>/dev/null | wc -l 2>/dev/null || echo "0")

# Limpar variáveis
READY_PODS=$(echo "$READY_PODS" | tr -d '\n\r' | xargs)
TOTAL_PODS=$(echo "$TOTAL_PODS" | tr -d '\n\r' | xargs)

if ! [[ "$READY_PODS" =~ ^[0-9]+$ ]]; then
    READY_PODS=0
fi
if ! [[ "$TOTAL_PODS" =~ ^[0-9]+$ ]]; then
    TOTAL_PODS=0
fi

echo "Pods Redis prontos: $READY_PODS/$TOTAL_PODS"
microk8s kubectl -n redis get pods
echo ""

# Verificar serviços
echo "🌐 Verificando serviços..."
microk8s kubectl -n redis get svc
echo ""

# Verificar proxy HAProxy
echo "🔄 Verificando proxy HAProxy..."
PROXY_PODS=$(microk8s kubectl get pods -n redis -l app=redis-proxy --no-headers 2>/dev/null | grep -c "Running" 2>/dev/null || echo "0")
PROXY_PODS=$(echo "$PROXY_PODS" | tr -d '\n\r' | xargs)

if ! [[ "$PROXY_PODS" =~ ^[0-9]+$ ]]; then
    PROXY_PODS=0
fi

echo "Pods HAProxy prontos: $PROXY_PODS"
if [ "$PROXY_PODS" -gt 0 ]; then
    echo "✅ HAProxy está funcionando"
else
    echo "❌ HAProxy não está funcionando"
    echo "Logs do HAProxy:"
    microk8s kubectl -n redis logs -l app=redis-proxy --tail=10
fi
echo ""

# Obter IP do nó para testes
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "📍 IP do nó Kubernetes: $NODE_IP"
echo ""

# Instruções de teste
echo "🧪 Comandos para testar a conexão:"
echo ""
echo "# Teste básico via proxy HAProxy:"
echo "redis-cli -h $NODE_IP -p 30379 -a Admin@123 ping"
echo ""
echo "# Teste com TLS:"
echo "redis-cli -h $NODE_IP -p 30380 --tls --insecure -a Admin@123 ping"
echo ""
echo "# Teste de escrita/leitura:"
echo "redis-cli -h $NODE_IP -p 30379 -a Admin@123 SET teste 'funcionando'"
echo "redis-cli -h $NODE_IP -p 30379 -a Admin@123 GET teste"
echo ""
echo "# Dashboard HAProxy:"
echo "http://$NODE_IP:30404/stats (admin/admin123)"
echo ""

echo "✅ Teste de instalação concluído!"