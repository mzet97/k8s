#!/bin/bash

# Script para verificar status e diagnosticar problemas do Redis
# Use este script após executar install-cert-manager.sh

set -e

echo "=== Diagnóstico do Redis no MicroK8s ==="

# Verificar se MicroK8s está rodando
echo "\n1. Verificando MicroK8s..."
microk8s status

# Verificar cert-manager
echo "\n2. Verificando cert-manager..."
microk8s kubectl get pods -n cert-manager

# Verificar namespace redis
echo "\n3. Verificando namespace redis..."
microk8s kubectl get namespace redis

# Verificar pods Redis
echo "\n4. Status dos pods Redis..."
microk8s kubectl get pods -n redis -o wide

# Verificar services
echo "\n5. Services Redis..."
microk8s kubectl get svc -n redis

# Verificar certificados
echo "\n6. Certificados..."
microk8s kubectl get certificates -n redis
microk8s kubectl describe certificate redis-server-cert -n redis

# Verificar secrets
echo "\n7. Secrets TLS..."
microk8s kubectl get secrets -n redis | grep -E "tls|ca"

# Verificar jobs
echo "\n8. Jobs de certificados..."
microk8s kubectl get jobs -n redis

# Verificar logs dos pods principais
echo "\n9. Logs dos pods (últimas 10 linhas)..."
echo "--- Redis Master ---"
microk8s kubectl logs redis-master-0 -n redis --tail=10 || echo "Erro ao obter logs do master"

echo "\n--- Redis Replica 0 ---"
microk8s kubectl logs redis-replica-0 -n redis --tail=10 || echo "Erro ao obter logs da replica 0"

echo "\n--- Redis Proxy ---"
PROXY_POD=$(microk8s kubectl get pods -n redis -l app=redis-proxy -o jsonpath='{.items[0].metadata.name}')
if [ ! -z "$PROXY_POD" ]; then
    microk8s kubectl logs $PROXY_POD -n redis --tail=10 || echo "Erro ao obter logs do proxy"
else
    echo "Pod do proxy não encontrado"
fi

# Verificar eventos recentes
echo "\n10. Eventos recentes no namespace redis..."
microk8s kubectl get events -n redis --sort-by='.lastTimestamp' | tail -10

# Teste de conectividade interna
echo "\n11. Teste de conectividade interna..."
echo "Testando resolução DNS interna..."
microk8s kubectl run redis-test --image=redis:7-alpine --rm -it --restart=Never -n redis -- \
  sh -c "nslookup redis-master.redis.svc.cluster.local" || echo "Teste DNS falhou"

# Informações de conexão
echo "\n12. Informações de conexão..."
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
EXTERNAL_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

echo "IP Interno do Node: $NODE_IP"
echo "IP Externo do Node: $EXTERNAL_IP"
echo "Porta TLS Externa: 30380"
echo "Porta Proxy Externa: 30379 (se habilitada)"

echo "\n=== Comandos de Teste ==="
echo "Conexão TLS (recomendada):"
echo "redis-cli -h $NODE_IP -p 30380 --tls --insecure -a Admin@123 ping"

echo "\nConexão via proxy (se disponível):"
echo "redis-cli -h $NODE_IP -p 30379 -a Admin@123 ping"

echo "\nConexão interna no cluster:"
echo "microk8s kubectl run redis-client --image=redis:7-alpine --rm -it --restart=Never -n redis -- \\"
echo "  redis-cli -h redis-master.redis.svc.cluster.local -p 6380 --tls --insecure -a Admin@123 ping"

# Verificar se há problemas conhecidos
echo "\n13. Diagnóstico de problemas..."

# Verificar se secrets existem
if ! microk8s kubectl get secret redis-tls-secret -n redis &>/dev/null; then
    echo "❌ PROBLEMA: Secret redis-tls-secret não encontrado"
    echo "   Solução: Execute novamente install-cert-manager.sh"
else
    echo "✅ Secret redis-tls-secret encontrado"
fi

if ! microk8s kubectl get secret redis-proxy-tls -n redis &>/dev/null; then
    echo "❌ PROBLEMA: Secret redis-proxy-tls não encontrado"
    echo "   Solução: Execute novamente install-cert-manager.sh"
else
    echo "✅ Secret redis-proxy-tls encontrado"
fi

# Verificar se certificados estão prontos
CERT_READY=$(microk8s kubectl get certificate redis-server-cert -n redis -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
if [ "$CERT_READY" = "True" ]; then
    echo "✅ Certificado redis-server-cert está pronto"
else
    echo "❌ PROBLEMA: Certificado redis-server-cert não está pronto (Status: $CERT_READY)"
    echo "   Verifique: microk8s kubectl describe certificate redis-server-cert -n redis"
fi

echo "\n=== Diagnóstico Concluído ==="