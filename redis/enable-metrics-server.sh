#!/bin/bash

# Script para habilitar metrics-server no MicroK8s

echo "🔧 Habilitando metrics-server no MicroK8s..."
echo ""

# Verificar se microk8s está disponível
if ! command -v microk8s &> /dev/null; then
    echo "❌ MicroK8s não encontrado."
    echo "💡 Este script é específico para MicroK8s."
    echo "💡 Para outros clusters, use: ./install-metrics-server.sh"
    exit 1
fi

# Verificar se MicroK8s está rodando
echo "📡 Verificando status do MicroK8s..."
if ! microk8s status --wait-ready --timeout 30 &> /dev/null; then
    echo "❌ MicroK8s não está rodando ou não está pronto."
    echo "💡 Execute: microk8s start"
    exit 1
fi

echo "✅ MicroK8s está rodando"
echo ""

# Verificar se metrics-server já está habilitado
echo "🔍 Verificando se metrics-server já está habilitado..."
if microk8s status | grep -q "metrics-server: enabled"; then
    echo "✅ Metrics-server já está habilitado"
else
    echo "📦 Habilitando metrics-server..."
    microk8s enable metrics-server
    
    if [ $? -eq 0 ]; then
        echo "✅ Metrics-server habilitado com sucesso"
    else
        echo "❌ Erro ao habilitar metrics-server"
        exit 1
    fi
fi

echo ""
echo "⏳ Aguardando metrics-server ficar pronto..."

# Aguardar o metrics-server ficar pronto
for i in {1..60}; do
    if microk8s kubectl get deployment metrics-server -n kube-system &> /dev/null; then
        if microk8s kubectl rollout status deployment/metrics-server -n kube-system --timeout=10s &> /dev/null; then
            echo "✅ Metrics-server está pronto"
            break
        fi
    fi
    
    if [ $i -eq 60 ]; then
        echo "⚠️  Timeout aguardando metrics-server ficar pronto"
        echo "💡 Verifique os logs: microk8s kubectl logs -n kube-system deployment/metrics-server"
    else
        echo "⏳ Aguardando... ($i/60)"
        sleep 5
    fi
done

echo ""
echo "🔍 Verificando status do metrics-server..."
microk8s kubectl get pods -n kube-system -l k8s-app=metrics-server

echo ""
echo "🧪 Testando coleta de métricas..."
echo "📊 Métricas de nós:"
microk8s kubectl top nodes 2>/dev/null || echo "⚠️  Métricas de nós ainda não disponíveis (aguarde alguns minutos)"

echo ""
echo "📊 Métricas de pods no namespace redis:"
microk8s kubectl top pods -n redis 2>/dev/null || echo "⚠️  Métricas de pods ainda não disponíveis (aguarde alguns minutos)"

echo ""
echo "🔍 Verificando status dos HPAs..."
microk8s kubectl get hpa -n redis 2>/dev/null || echo "⚠️  Nenhum HPA encontrado no namespace redis"

echo ""
echo "💡 Próximos passos:"
echo "   1. Aguarde alguns minutos para as métricas ficarem disponíveis"
echo "   2. Verifique se os HPAs estão funcionando: microk8s kubectl describe hpa -n redis"
echo "   3. Se ainda houver problemas, execute: ./fix-hpa-issues.sh"
echo ""
echo "✅ Metrics-server habilitado no MicroK8s!"