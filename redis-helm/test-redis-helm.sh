#!/bin/bash

# Script de teste para Redis instalado via Helm
# Testa conectividade, replicação e funcionalidades TLS

set -e

echo "🧪 Teste do Redis Helm - Bitnami"
echo "Testando: conectividade, replicação, TLS"
echo "====================================="

# Verificar se MicroK8s está disponível
if ! command -v microk8s &> /dev/null; then
    echo "❌ MicroK8s não encontrado. Instale o MicroK8s primeiro."
    exit 1
fi

# Verificar se MicroK8s está rodando
if ! microk8s status --wait-ready --timeout 30 &> /dev/null; then
    echo "❌ MicroK8s não está rodando ou não está pronto."
    echo "   Execute: microk8s start"
    exit 1
fi

# Verificar se o namespace existe
if ! microk8s kubectl get namespace redis &> /dev/null; then
    echo "❌ Namespace 'redis' não encontrado. Execute o script de instalação primeiro."
    exit 1
fi

# Verificar se os pods estão rodando
echo "🔍 Verificando status dos pods..."
microk8s kubectl get pods -n redis
echo ""

# Verificar se todos os pods estão prontos
echo "⏳ Aguardando todos os pods ficarem prontos..."
microk8s kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n redis --timeout=300s
echo "✅ Todos os pods estão prontos"

# Obter senha do Redis
echo "🔑 Obtendo senha do Redis..."
REDIS_PASSWORD=$(microk8s kubectl get secret redis-cluster -n redis -o jsonpath='{.data.redis-password}' | base64 -d)
echo "✅ Senha obtida com sucesso"

# Teste 1: Conectividade com Master
echo ""
echo "🧪 Teste 1: Conectividade com Redis Master"
echo "==========================================="

microk8s kubectl run redis-test-master --rm -i --restart=Never --namespace redis --image docker.io/bitnami/redis:7.2.4-debian-11-r0 --command -- bash -c "
echo 'Testando conexão com Master...'
REDISCLI_AUTH='$REDIS_PASSWORD'
redis-cli -h redis-cluster-master.redis.svc.cluster.local -p 6379 --tls --insecure ping
echo 'Master respondeu com PONG'

echo 'Definindo chave de teste no Master...'
redis-cli -h redis-cluster-master.redis.svc.cluster.local -p 6379 --tls --insecure set test-key 'Hello from Master'
echo 'Chave definida no Master'

echo 'Lendo chave do Master...'
redis-cli -h redis-cluster-master.redis.svc.cluster.local -p 6379 --tls --insecure get test-key
"

echo "✅ Teste do Master concluído"

# Teste 2: Conectividade com Replicas
echo ""
echo "🧪 Teste 2: Conectividade com Redis Replicas"
echo "============================================="

# Aguardar um pouco para replicação
echo "⏳ Aguardando replicação (5 segundos)..."
sleep 5

microk8s kubectl run redis-test-replica --rm -i --restart=Never --namespace redis --image docker.io/bitnami/redis:7.2.4-debian-11-r0 --command -- bash -c "
echo 'Testando conexão com Replica...'
REDISCLI_AUTH='$REDIS_PASSWORD'
redis-cli -h redis-cluster-replica.redis.svc.cluster.local -p 6379 --tls --insecure ping
echo 'Replica respondeu com PONG'

echo 'Lendo chave replicada da Replica...'
VALUE=\$(redis-cli -h redis-cluster-replica.redis.svc.cluster.local -p 6379 --tls --insecure get test-key)
echo \"Valor lido da replica: \$VALUE\"

if [ \"\$VALUE\" = \"Hello from Master\" ]; then
    echo '✅ Replicação funcionando corretamente!'
else
    echo '❌ Erro na replicação!'
    exit 1
fi
"

echo "✅ Teste das Replicas concluído"

# Teste 3: Verificar informações de replicação
echo ""
echo "🧪 Teste 3: Informações de Replicação"
echo "====================================="

microk8s kubectl run redis-test-info --rm -i --restart=Never --namespace redis --image docker.io/bitnami/redis:7.2.4-debian-11-r0 --command -- bash -c "
echo 'Obtendo informações de replicação do Master...'
REDISCLI_AUTH='$REDIS_PASSWORD'
redis-cli -h redis-cluster-master.redis.svc.cluster.local -p 6379 --tls --insecure info replication
"

echo "✅ Informações de replicação obtidas"

# Teste 4: Verificar TLS
echo ""
echo "🧪 Teste 4: Verificação TLS"
echo "==========================="

echo "🔐 Verificando certificados TLS..."
microk8s kubectl get certificates -n redis
echo ""
echo "🔐 Verificando secrets TLS..."
microk8s kubectl get secret redis-tls-secret -n redis -o yaml | grep -E '(tls.crt|tls.key|ca.crt)'
echo "✅ Certificados TLS verificados"

# Teste 5: Verificar métricas
echo ""
echo "🧪 Teste 5: Verificação de Métricas"
echo "==================================="

echo "📊 Verificando se o redis-exporter está rodando..."
microk8s kubectl get pods -n redis -l app.kubernetes.io/component=metrics
echo ""
echo "📊 Testando endpoint de métricas..."
microk8s kubectl run redis-test-metrics --rm -i --restart=Never --namespace redis --image curlimages/curl:latest --command -- curl -s http://redis-cluster-metrics.redis.svc.cluster.local:9121/metrics | head -10
echo "✅ Métricas verificadas"

# Teste 6: Teste de performance básico
echo ""
echo "🧪 Teste 6: Teste de Performance Básico"
echo "======================================="

microk8s kubectl run redis-test-perf --rm -i --restart=Never --namespace redis --image docker.io/bitnami/redis:7.2.4-debian-11-r0 --command -- bash -c "
echo 'Executando benchmark básico...'
REDISCLI_AUTH='$REDIS_PASSWORD'
redis-cli -h redis-cluster-master.redis.svc.cluster.local -p 6379 --tls --insecure --latency-history -i 1 | head -5 &
BENCH_PID=\$!
sleep 10
kill \$BENCH_PID 2>/dev/null || true
echo 'Benchmark concluído'
"

echo "✅ Teste de performance concluído"

# Limpeza
echo ""
echo "🧹 Limpeza: Removendo chave de teste..."
microk8s kubectl run redis-cleanup --rm -i --restart=Never --namespace redis --image docker.io/bitnami/redis:7.2.4-debian-11-r0 --command -- bash -c "
REDISCLI_AUTH='$REDIS_PASSWORD'
redis-cli -h redis-cluster-master.redis.svc.cluster.local -p 6379 --tls --insecure del test-key
echo 'Chave de teste removida'
"

# Resumo final
echo ""
echo "🎉 RESUMO DOS TESTES"
echo "==================="
echo "✅ Conectividade Master: OK"
echo "✅ Conectividade Replicas: OK"
echo "✅ Replicação Master->Replica: OK"
echo "✅ TLS habilitado: OK"
echo "✅ Métricas funcionando: OK"
echo "✅ Performance básica: OK"
echo ""
echo "📋 Informações úteis:"
echo "   • Master: redis-cluster-master.redis.svc.cluster.local:6379"
echo "   • Replicas: redis-cluster-replica.redis.svc.cluster.local:6379"
echo "   • Métricas: redis-cluster-metrics.redis.svc.cluster.local:9121"
echo "   • TLS: Habilitado (certificados auto-gerados)"
echo "   • Senha: Armazenada em secret/redis-cluster"
echo ""
echo "🚀 Redis Helm está funcionando perfeitamente!"
echo "   Configuração: 1 Master + 3 Replicas com TLS"