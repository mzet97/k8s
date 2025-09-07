#!/bin/bash

# Script para diagnosticar e corrigir problemas comuns na instalação do Redis

echo "🔧 Diagnóstico e correção de problemas na instalação do Redis..."
echo ""

# Função para verificar se um comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar pré-requisitos
echo "📋 Verificando pré-requisitos..."
if ! command_exists microk8s; then
    echo "❌ MicroK8s não está instalado ou não está no PATH"
    exit 1
fi

if ! microk8s status --wait-ready >/dev/null 2>&1; then
    echo "❌ MicroK8s não está funcionando corretamente"
    echo "Tente: microk8s start"
    exit 1
fi

echo "✅ MicroK8s está funcionando"
echo ""

# Verificar cert-manager
echo "🔐 Verificando cert-manager..."
if ! microk8s kubectl get namespace cert-manager >/dev/null 2>&1; then
    echo "❌ cert-manager não está instalado"
    echo "Instalando cert-manager..."
    if [ -f "install-cert-manager.sh" ]; then
        chmod +x install-cert-manager.sh
        ./install-cert-manager.sh
    else
        echo "Script install-cert-manager.sh não encontrado"
        echo "Instale manualmente: microk8s enable cert-manager"
    fi
else
    echo "✅ cert-manager está instalado"
fi
echo ""

# Verificar pods com problemas
echo "🚀 Verificando pods com problemas..."
PROBLEM_PODS=$(microk8s kubectl get pods -n redis --no-headers 2>/dev/null | grep -E "Error|CrashLoopBackOff|ImagePullBackOff|Pending" || echo "")

if [ -n "$PROBLEM_PODS" ]; then
    echo "❌ Pods com problemas encontrados:"
    echo "$PROBLEM_PODS"
    echo ""
    
    # Verificar logs dos pods com erro
    echo "📋 Logs dos pods com problemas:"
    microk8s kubectl get pods -n redis --no-headers 2>/dev/null | grep -E "Error|CrashLoopBackOff" | while read pod_line; do
        POD_NAME=$(echo "$pod_line" | awk '{print $1}')
        echo "--- Logs do pod $POD_NAME ---"
        microk8s kubectl -n redis logs "$POD_NAME" --tail=20 2>/dev/null || echo "Não foi possível obter logs"
        echo ""
    done
    
    # Tentar reiniciar pods com problema
    echo "🔄 Tentando reiniciar pods com problemas..."
    microk8s kubectl get pods -n redis --no-headers 2>/dev/null | grep -E "Error|CrashLoopBackOff" | while read pod_line; do
        POD_NAME=$(echo "$pod_line" | awk '{print $1}')
        echo "Reiniciando pod $POD_NAME..."
        microk8s kubectl -n redis delete pod "$POD_NAME" 2>/dev/null || echo "Falha ao reiniciar $POD_NAME"
    done
else
    echo "✅ Nenhum pod com problemas encontrado"
fi
echo ""

# Verificar certificados TLS
echo "🔐 Verificando certificados TLS..."
if ! microk8s kubectl get secret redis-tls-secret -n redis >/dev/null 2>&1; then
    echo "❌ Secret redis-tls-secret não encontrado"
    echo "Tentando recriar certificados..."
    
    # Remover certificados antigos
    microk8s kubectl delete certificate redis-server-cert -n redis 2>/dev/null || true
    microk8s kubectl delete secret redis-tls-secret -n redis 2>/dev/null || true
    
    # Recriar certificados
    echo "Recriando certificados TLS..."
    microk8s kubectl apply -f 02-tls-certificates.yaml
    
    # Aguardar certificados
    echo "Aguardando certificados serem criados..."
    for i in {1..24}; do
        if microk8s kubectl get secret redis-tls-secret -n redis >/dev/null 2>&1; then
            echo "✅ Certificados TLS recriados com sucesso!"
            break
        fi
        echo "Tentativa $i/24: Aguardando certificados..."
        sleep 5
    done
else
    echo "✅ Certificados TLS estão OK"
fi
echo ""

# Verificar conectividade de rede
echo "🌐 Verificando conectividade de rede..."
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
if [ -n "$NODE_IP" ]; then
    echo "IP do nó: $NODE_IP"
    
    # Verificar se as portas estão abertas
    echo "Verificando portas..."
    for port in 30379 30380 30381 30382 30404; do
        if ss -tlnp 2>/dev/null | grep -q ":$port "; then
            echo "✅ Porta $port está aberta"
        else
            echo "❌ Porta $port não está aberta"
        fi
    done
else
    echo "❌ Não foi possível obter o IP do nó"
fi
echo ""

# Verificar recursos do sistema
echo "💾 Verificando recursos do sistema..."
echo "Uso de CPU e memória dos pods Redis:"
microk8s kubectl top pods -n redis 2>/dev/null || echo "Metrics server não disponível"
echo ""

# Sugestões de correção
echo "💡 Sugestões de correção:"
echo ""
echo "1. Se os pods estão em CrashLoopBackOff:"
echo "   - Verifique os logs: microk8s kubectl -n redis logs <pod-name>"
echo "   - Verifique se há recursos suficientes no nó"
echo ""
echo "2. Se os certificados TLS não são criados:"
echo "   - Verifique se o cert-manager está funcionando:"
echo "     microk8s kubectl -n cert-manager get pods"
echo "   - Verifique os logs do cert-manager:"
echo "     microk8s kubectl -n cert-manager logs -l app=cert-manager"
echo ""
echo "3. Se o HAProxy não inicia:"
echo "   - Verifique se os certificados TLS existem"
echo "   - Verifique se o ConfigMap redis-proxy-config está correto"
echo ""
echo "4. Para reinstalar completamente:"
echo "   - Execute: ./remove-redis.sh"
echo "   - Aguarde a limpeza completa"
echo "   - Execute: ./install-redis.sh"
echo ""

echo "✅ Diagnóstico concluído!"