#!/usr/bin/env bash

# Script de verificação de status do Coder
# Mostra informações detalhadas sobre a instalação

set -euo pipefail

echo "📊 Status do Coder no Kubernetes"
echo "==============================="
echo ""

# Verificar se MicroK8s está disponível
if ! command -v microk8s &> /dev/null; then
    echo "❌ Erro: MicroK8s não encontrado."
    exit 1
fi

# Verificar se MicroK8s está rodando
if ! microk8s status --wait-ready --timeout 10 &> /dev/null; then
    echo "❌ Erro: MicroK8s não está pronto."
    echo "   Execute: microk8s start"
    exit 1
fi

echo "✅ MicroK8s está operacional"
echo ""

# Verificar se o namespace existe
if ! microk8s kubectl get namespace coder &> /dev/null; then
    echo "❌ Namespace 'coder' não encontrado."
    echo "   Execute: ./00-prereqs.sh"
    exit 1
fi

echo "✅ Namespace 'coder' encontrado"
echo ""

# 1. Status geral dos recursos
echo "📦 1. RECURSOS KUBERNETES"
echo "========================"
echo "📊 Pods, Services e Ingress:"
microk8s kubectl -n coder get pods,svc,ingress -o wide
echo ""

# 2. Status do Helm
echo "⚙️  2. STATUS DO HELM"
echo "=================="
if microk8s helm3 version &> /dev/null; then
    echo "📋 Releases do Helm no namespace coder:"
    microk8s helm3 list -n coder
    echo ""
    
    if microk8s helm3 list -n coder | grep -q "coder"; then
        echo "📊 Detalhes da release:"
        microk8s helm3 status coder -n coder
        echo ""
    fi
else
    echo "⚠️  Helm3 não está habilitado"
fi

# 3. Status dos Deployments
echo "🚀 3. STATUS DOS DEPLOYMENTS"
echo "============================"
echo "📊 Deployments:"
microk8s kubectl -n coder get deployments -o wide
echo ""

echo "📊 ReplicaSets:"
microk8s kubectl -n coder get replicasets -o wide
echo ""

# 4. Status dos volumes
echo "💾 4. VOLUMES PERSISTENTES"
echo "=========================="
echo "📊 PVCs no namespace coder:"
microk8s kubectl -n coder get pvc -o wide
echo ""

echo "📊 PVs relacionados ao coder:"
microk8s kubectl get pv | grep -E "(NAME|coder)" || echo "Nenhum PV encontrado"
echo ""

# 5. Status dos certificados
echo "🔒 5. CERTIFICADOS TLS"
echo "====================="
echo "📊 Certificados:"
microk8s kubectl -n coder get certificates -o wide 2>/dev/null || echo "Nenhum certificado encontrado"
echo ""

if microk8s kubectl -n coder get certificate coder-tls &> /dev/null; then
    echo "📋 Detalhes do certificado coder-tls:"
    microk8s kubectl -n coder describe certificate coder-tls
    echo ""
fi

# 6. Status dos secrets
echo "🔐 6. SECRETS"
echo "============"
echo "📊 Secrets no namespace coder:"
microk8s kubectl -n coder get secrets -o wide
echo ""

# 7. Status da rede
echo "🌐 7. CONFIGURAÇÃO DE REDE"
echo "=========================="
echo "📊 Endpoints:"
microk8s kubectl -n coder get endpoints -o wide
echo ""

echo "📊 NetworkPolicies:"
microk8s kubectl -n coder get networkpolicies -o wide 2>/dev/null || echo "Nenhuma NetworkPolicy encontrada"
echo ""

# 8. Status dos eventos
echo "📝 8. EVENTOS RECENTES"
echo "====================="
echo "📊 Últimos eventos no namespace coder:"
microk8s kubectl -n coder get events --sort-by='.lastTimestamp' | tail -10
echo ""

# 9. Logs da aplicação
echo "📋 9. LOGS DA APLICAÇÃO"
echo "======================="
if microk8s kubectl -n coder get deployment coder &> /dev/null; then
    echo "📝 Últimas 20 linhas dos logs do Coder:"
    microk8s kubectl -n coder logs deployment/coder --tail=20 | tail -n +1 || echo "⚠️  Não foi possível obter logs"
    echo ""
else
    echo "⚠️  Deployment 'coder' não encontrado"
fi

# 10. Verificação de saúde
echo "🏥 10. VERIFICAÇÃO DE SAÚDE"
echo "==========================="

# Verificar se os pods estão rodando
READY_PODS=$(microk8s kubectl -n coder get pods --no-headers | grep -c "Running" || echo "0")
TOTAL_PODS=$(microk8s kubectl -n coder get pods --no-headers | wc -l || echo "0")

echo "📊 Pods: $READY_PODS/$TOTAL_PODS rodando"

# Verificar se o service está disponível
if microk8s kubectl -n coder get service coder &> /dev/null; then
    echo "✅ Service 'coder' está disponível"
else
    echo "❌ Service 'coder' não encontrado"
fi

# Verificar se o ingress está configurado
if microk8s kubectl -n coder get ingress coder &> /dev/null; then
    echo "✅ Ingress 'coder' está configurado"
    INGRESS_HOST=$(microk8s kubectl -n coder get ingress coder -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "N/A")
    echo "🌐 Host configurado: $INGRESS_HOST"
else
    echo "⚠️  Ingress 'coder' não encontrado"
fi

# Verificar conectividade interna
echo ""
echo "🔍 Testando conectividade interna..."
if microk8s kubectl -n coder get service coder &> /dev/null; then
    SERVICE_IP=$(microk8s kubectl -n coder get service coder -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "N/A")
    SERVICE_PORT=$(microk8s kubectl -n coder get service coder -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "N/A")
    echo "📡 Service IP: $SERVICE_IP:$SERVICE_PORT"
fi

echo ""
echo "📋 RESUMO DO STATUS"
echo "=================="
if [ "$READY_PODS" -gt 0 ] && [ "$READY_PODS" -eq "$TOTAL_PODS" ]; then
    echo "✅ Status geral: SAUDÁVEL"
    echo "✅ Todos os pods estão rodando"
else
    echo "⚠️  Status geral: ATENÇÃO NECESSÁRIA"
    echo "⚠️  Nem todos os pods estão rodando"
fi

echo ""
echo "🔧 COMANDOS ÚTEIS"
echo "================="
echo "📝 Ver logs em tempo real:"
echo "   microk8s kubectl -n coder logs -f deployment/coder"
echo ""
echo "🔄 Reiniciar deployment:"
echo "   microk8s kubectl -n coder rollout restart deployment/coder"
echo ""
echo "🔍 Diagnóstico detalhado:"
echo "   microk8s kubectl -n coder describe pod <pod-name>"
echo ""
echo "🌐 Port-forward para teste local:"
echo "   microk8s kubectl -n coder port-forward service/coder 8080:80"
echo ""
