#!/bin/bash

# Script para instalar o metrics-server necessário para HPA

echo "🔧 Instalando metrics-server para suporte ao HPA..."
echo ""

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não encontrado. Verifique se está instalado e no PATH."
    exit 1
fi

# Verificar se o cluster está acessível
echo "📡 Verificando conectividade com o cluster..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Não foi possível conectar ao cluster Kubernetes."
    echo "💡 Dica: Verifique se o cluster está rodando e o kubeconfig está configurado."
    exit 1
fi

echo "✅ Cluster acessível"
echo ""

# Instalar metrics-server
echo "📦 Instalando metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

if [ $? -eq 0 ]; then
    echo "✅ Metrics-server instalado com sucesso"
else
    echo "❌ Erro ao instalar metrics-server"
    exit 1
fi

echo ""
echo "⏳ Aguardando metrics-server ficar pronto..."

# Aguardar o metrics-server ficar pronto
for i in {1..60}; do
    if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
        if kubectl rollout status deployment/metrics-server -n kube-system --timeout=10s &> /dev/null; then
            echo "✅ Metrics-server está pronto"
            break
        fi
    fi
    
    if [ $i -eq 60 ]; then
        echo "⚠️  Timeout aguardando metrics-server ficar pronto"
        echo "💡 Verifique os logs: kubectl logs -n kube-system deployment/metrics-server"
    else
        echo "⏳ Aguardando... ($i/60)"
        sleep 5
    fi
done

echo ""
echo "🔍 Verificando status do metrics-server..."
kubectl get pods -n kube-system -l k8s-app=metrics-server

echo ""
echo "🧪 Testando coleta de métricas..."
echo "📊 Métricas de nós:"
kubectl top nodes 2>/dev/null || echo "⚠️  Métricas de nós ainda não disponíveis"

echo ""
echo "📊 Métricas de pods no namespace redis:"
kubectl top pods -n redis 2>/dev/null || echo "⚠️  Métricas de pods ainda não disponíveis"

echo ""
echo "🔍 Verificando status dos HPAs..."
kubectl get hpa -n redis

echo ""
echo "💡 Dicas importantes:"
echo "   - Pode levar alguns minutos para as métricas ficarem disponíveis"
echo "   - Se o metrics-server não funcionar, pode ser necessário configurar --kubelet-insecure-tls"
echo "   - Para MicroK8s, use: microk8s enable metrics-server"
echo ""
echo "✅ Instalação do metrics-server concluída!"