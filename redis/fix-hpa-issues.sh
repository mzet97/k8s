#!/bin/bash

# Script para corrigir problemas com HPA (HorizontalPodAutoscaler)

echo "🔧 Corrigindo problemas com HPA do Redis..."
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

# 1. Verificar se metrics-server está instalado
echo "🔍 Verificando metrics-server..."
if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    echo "✅ Metrics-server encontrado"
    
    # Verificar se está rodando
    if kubectl get pods -n kube-system -l k8s-app=metrics-server --field-selector=status.phase=Running | grep -q metrics-server; then
        echo "✅ Metrics-server está rodando"
    else
        echo "⚠️  Metrics-server não está rodando corretamente"
        echo "📋 Status dos pods do metrics-server:"
        kubectl get pods -n kube-system -l k8s-app=metrics-server
    fi
else
    echo "❌ Metrics-server não encontrado"
    echo "💡 Para instalar: ./install-metrics-server.sh"
    echo "💡 Para MicroK8s: microk8s enable metrics-server"
fi

echo ""

# 2. Verificar HPAs problemáticos
echo "🔍 Verificando HPAs no namespace redis..."
kubectl get hpa -n redis

echo ""
echo "📋 Detalhes dos HPAs:"
kubectl describe hpa -n redis

echo ""

# 3. Verificar se os deployments referenciados pelos HPAs existem
echo "🔍 Verificando deployments referenciados pelos HPAs..."

# Verificar redis-proxy deployment
if kubectl get deployment redis-proxy -n redis &> /dev/null; then
    echo "✅ Deployment redis-proxy encontrado"
else
    echo "❌ Deployment redis-proxy não encontrado"
fi

# Verificar redis-exporter-replica deployment
if kubectl get deployment redis-exporter-replica -n redis &> /dev/null; then
    echo "✅ Deployment redis-exporter-replica encontrado"
else
    echo "❌ Deployment redis-exporter-replica não encontrado"
    echo "💡 Este deployment pode estar em outro arquivo ou não ter sido aplicado"
fi

echo ""

# 4. Verificar se os pods têm resource requests definidos
echo "🔍 Verificando resource requests nos deployments..."

echo "📊 Resources do deployment redis-proxy:"
kubectl get deployment redis-proxy -n redis -o jsonpath='{.spec.template.spec.containers[0].resources}' 2>/dev/null | jq . 2>/dev/null || echo "Sem resources definidos ou jq não disponível"

echo ""
echo "📊 Resources do deployment redis-exporter-replica:"
kubectl get deployment redis-exporter-replica -n redis -o jsonpath='{.spec.template.spec.containers[0].resources}' 2>/dev/null | jq . 2>/dev/null || echo "Deployment não encontrado ou sem resources definidos"

echo ""

# 5. Testar coleta de métricas
echo "🧪 Testando coleta de métricas..."
echo "📊 Métricas de nós:"
kubectl top nodes 2>/dev/null || echo "⚠️  Métricas de nós não disponíveis"

echo ""
echo "📊 Métricas de pods no namespace redis:"
kubectl top pods -n redis 2>/dev/null || echo "⚠️  Métricas de pods não disponíveis"

echo ""

# 6. Sugestões de correção
echo "💡 Sugestões de correção:"
echo ""
echo "1. Se metrics-server não está instalado:"
echo "   - Para MicroK8s: microk8s enable metrics-server"
echo "   - Para outros clusters: ./install-metrics-server.sh"
echo ""
echo "2. Se o deployment redis-exporter-replica não existe:"
echo "   - Verifique se o arquivo 60-monitoring.yaml foi aplicado"
echo "   - Execute: kubectl apply -f 60-monitoring.yaml"
echo ""
echo "3. Se os pods não têm resource requests:"
echo "   - HPAs precisam de resource requests para funcionar"
echo "   - Adicione requests de CPU e memória nos deployments"
echo ""
echo "4. Para remover HPAs problemáticos temporariamente:"
echo "   - kubectl delete hpa redis-exporter-replica-hpa -n redis"
echo "   - kubectl delete hpa redis-proxy-hpa -n redis"
echo ""
echo "5. Para recriar HPAs após corrigir os deployments:"
echo "   - kubectl apply -f 70-high-availability.yaml"
echo ""
echo "✅ Diagnóstico de HPA concluído!"