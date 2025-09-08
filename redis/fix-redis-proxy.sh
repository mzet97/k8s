#!/bin/bash

# Script para diagnosticar e corrigir problemas dos pods redis-proxy
# Versão para Windows (usando kubectl diretamente)

echo "🔍 Diagnóstico dos pods redis-proxy..."
echo "==========================================="

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não encontrado. Instale o kubectl ou use o contexto apropriado."
    echo "💡 Alternativas:"
    echo "   - Instale kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
    echo "   - Use Docker Desktop com Kubernetes habilitado"
    echo "   - Use minikube kubectl -- ao invés de kubectl"
    exit 1
fi

# 1. Verificar status dos pods redis-proxy
echo "1️⃣ Status atual dos pods redis-proxy:"
kubectl get pods -n redis -l app=redis-proxy
echo ""

# 2. Verificar logs dos pods com erro
echo "2️⃣ Logs dos pods redis-proxy com erro:"
ERROR_PODS=$(kubectl get pods -n redis -l app=redis-proxy --no-headers | grep Error | awk '{print $1}')

if [ -n "$ERROR_PODS" ]; then
    for pod in $ERROR_PODS; do
        echo "📋 Logs do pod $pod:"
        kubectl logs -n redis $pod --tail=50
        echo "----------------------------------------"
    done
else
    echo "✅ Nenhum pod redis-proxy em estado de erro encontrado"
fi
echo ""

# 3. Verificar se o secret redis-proxy-tls existe
echo "3️⃣ Verificando secret redis-proxy-tls:"
if kubectl get secret redis-proxy-tls -n redis >/dev/null 2>&1; then
    echo "✅ Secret redis-proxy-tls existe"
    kubectl describe secret redis-proxy-tls -n redis
else
    echo "❌ Secret redis-proxy-tls não encontrado"
    echo "🔧 Aplicando manifesto para gerar certificados..."
    
    # Aplicar o job de geração de certificados
    kubectl apply -f 42-redis-proxy-tls.yaml
    
    echo "⏳ Aguardando job de geração de certificados..."
    kubectl wait --for=condition=complete job/redis-proxy-cert-generator -n redis --timeout=120s
    
    if [ $? -eq 0 ]; then
        echo "✅ Certificados gerados com sucesso"
    else
        echo "❌ Falha na geração de certificados"
        echo "📋 Logs do job:"
        kubectl logs -n redis job/redis-proxy-cert-generator
        echo "📋 Status do job:"
        kubectl describe job redis-proxy-cert-generator -n redis
        exit 1
    fi
fi
echo ""

# 4. Verificar se os serviços Redis estão funcionando
echo "4️⃣ Verificando conectividade com Redis:"
echo "📋 Verificando se pods Redis estão rodando:"
kubectl get pods -n redis -l 'app in (redis-master,redis-replica)'

echo "📋 Testando conexão com Redis Master (se disponível):"
kubectl exec -n redis redis-master-0 -- redis-cli --tls \
    --cert /tls/tls.crt \
    --key /tls/tls.key \
    --cacert /tls/ca.crt \
    -h redis-master.redis.svc.cluster.local -p 6380 \
    -a "Admin@123" ping 2>/dev/null && echo "✅ Redis Master OK" || echo "❌ Falha na conexão com Redis Master"
echo ""

# 5. Verificar configuração do HAProxy
echo "5️⃣ Verificando configuração do HAProxy:"
echo "📋 ConfigMap redis-proxy-config:"
kubectl get configmap redis-proxy-config -n redis >/dev/null 2>&1 && echo "✅ ConfigMap existe" || echo "❌ ConfigMap não encontrado"
echo ""

# 6. Reiniciar deployment redis-proxy se necessário
echo "6️⃣ Reiniciando deployment redis-proxy:"
kubectl rollout restart deployment/redis-proxy -n redis
echo "⏳ Aguardando rollout..."
kubectl rollout status deployment/redis-proxy -n redis --timeout=120s

if [ $? -eq 0 ]; then
    echo "✅ Deployment redis-proxy reiniciado com sucesso"
else
    echo "❌ Falha no rollout do deployment"
    echo "📋 Status do deployment:"
    kubectl describe deployment redis-proxy -n redis
    echo "📋 Events do namespace:"
    kubectl get events -n redis --sort-by='.lastTimestamp' | tail -10
fi
echo ""

# 7. Verificar status final
echo "7️⃣ Status final dos pods redis-proxy:"
kubectl get pods -n redis -l app=redis-proxy
echo ""

# 8. Testar conectividade através do proxy
echo "8️⃣ Testando conectividade através do proxy:"
echo "⏳ Aguardando pods estarem prontos..."
kubectl wait --for=condition=ready pod -l app=redis-proxy -n redis --timeout=60s

if [ $? -eq 0 ]; then
    echo "✅ Pods redis-proxy estão prontos"
    
    # Obter IP do nó
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    if [ -n "$NODE_IP" ]; then
        echo "📋 IP do nó: $NODE_IP"
        echo "📋 Portas disponíveis:"
        echo "   - Redis sem TLS: $NODE_IP:30379"
        echo "   - Redis com TLS: $NODE_IP:30380"
        echo "   - Dashboard HAProxy: $NODE_IP:30404"
        
        # Testar se redis-cli está disponível
        if command -v redis-cli &> /dev/null; then
            echo "📋 Testando conexão externa (sem TLS):"
            timeout 10 redis-cli -h $NODE_IP -p 30379 -a "Admin@123" ping 2>/dev/null && echo "✅ Conexão sem TLS OK" || echo "❌ Falha na conexão sem TLS"
            
            echo "📋 Testando conexão externa (com TLS):"
            timeout 10 redis-cli -h $NODE_IP -p 30380 --tls --insecure -a "Admin@123" ping 2>/dev/null && echo "✅ Conexão com TLS OK" || echo "❌ Falha na conexão com TLS"
        else
            echo "⚠️ redis-cli não disponível para testes externos"
        fi
        
        # Testar dashboard HAProxy
        if command -v curl &> /dev/null; then
            echo "📋 Testando dashboard HAProxy:"
            curl -s --connect-timeout 5 http://$NODE_IP:30404/stats >/dev/null && echo "✅ Dashboard HAProxy acessível" || echo "❌ Dashboard HAProxy inacessível"
        else
            echo "⚠️ curl não disponível para teste do dashboard"
        fi
    else
        echo "❌ Não foi possível obter IP do nó"
    fi
else
    echo "❌ Pods redis-proxy não ficaram prontos"
    echo "📋 Logs dos pods:"
    kubectl logs -n redis -l app=redis-proxy --tail=20
    echo "📋 Describe dos pods:"
    kubectl describe pods -n redis -l app=redis-proxy
fi
echo ""

echo "🎯 Diagnóstico concluído!"
echo "==========================================="
echo "📋 Para monitorar continuamente:"
echo "   kubectl get pods -n redis -l app=redis-proxy -w"
echo ""
echo "📋 Para verificar logs:"
echo "   kubectl logs -n redis -l app=redis-proxy -f"
echo ""
echo "📋 Para acessar dashboard HAProxy (se disponível):"
echo "   http://NODE_IP:30404/stats (admin/admin123)"
echo ""
echo "📋 Para testar conexões (se redis-cli disponível):"
echo "   redis-cli -h NODE_IP -p 30379 -a Admin@123 ping  # Sem TLS"
echo "   redis-cli -h NODE_IP -p 30380 --tls --insecure -a Admin@123 ping  # Com TLS"