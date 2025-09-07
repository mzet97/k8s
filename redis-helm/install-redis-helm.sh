#!/bin/bash

# Script de instalação do Redis usando Helm Chart Bitnami
# Configuração: 1 master + 3 replicas com TLS e DNS

set -e

echo "🚀 Instalação do Redis com Helm (Bitnami)"
echo "Configuração: 1 master + 3 replicas, TLS habilitado"
echo "================================================"

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não encontrado. Instale o kubectl primeiro."
    exit 1
fi

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

# Habilitar addon do Helm no MicroK8s
echo "📦 Habilitando addon Helm no MicroK8s..."
microk8s enable helm3
echo "✅ Helm habilitado no MicroK8s"

# Verificar conectividade com cluster
echo "🔍 Verificando conectividade com o cluster..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Não foi possível conectar ao cluster Kubernetes."
    echo "   Verifique sua configuração do kubectl."
    exit 1
fi

echo "✅ Conectividade com cluster verificada"

# Passo 1: Adicionar repositório Bitnami
echo "📦 Passo 1: Adicionando repositório Bitnami..."
microk8s helm3 repo add bitnami https://charts.bitnami.com/bitnami
microk8s helm3 repo update
echo "✅ Repositório Bitnami adicionado e atualizado"

# Passo 2: Criar namespace
echo "🏗️  Passo 2: Criando namespace redis..."
microk8s kubectl create namespace redis --dry-run=client -o yaml | microk8s kubectl apply -f -
echo "✅ Namespace redis criado/verificado"

# Passo 3: Pular configuração TLS (temporariamente para debug)
echo "⚠️  Passo 3: Pulando configuração TLS para debug..."
echo "✅ Configuração TLS pulada"

# Passo 4: Instalar Redis com Helm (sem TLS)
echo "🚀 Passo 4: Instalando Redis com Helm (sem TLS para debug)..."
microk8s helm3 upgrade --install redis-cluster bitnami/redis \
  --namespace redis \
  --values values.yaml \
  --set global.security.allowInsecureImages=true \
  --set master.persistence.enabled=false \
  --set replica.persistence.enabled=false \
  --set tls.enabled=false \
  --wait --timeout=900s

echo "✅ Redis instalado com sucesso!"

# Passo 5: Aguardar pods ficarem prontos
echo "⏳ Passo 5: Aguardando pods Redis ficarem prontos..."
microk8s kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n redis --timeout=300s
echo "✅ Todos os pods Redis estão prontos"

# Passo 6: Aplicar HPA (Horizontal Pod Autoscaler)
echo "📈 Passo 6: Configurando HPA para replicas..."
microk8s kubectl apply -f hpa-config.yaml
echo "✅ HPA configurado para autoscaling das replicas"

# Passo 7: Verificar status da instalação
echo "🔍 Passo 7: Verificando status da instalação..."
echo "📊 Status dos pods:"
microk8s kubectl get pods -n redis
echo ""
echo "📊 Status dos services:"
microk8s kubectl get svc -n redis
echo ""
echo "📊 Status do HPA:"
microk8s kubectl get hpa -n redis
echo "✅ Verificação concluída!"

# Passo 8: Obter informações de conexão
echo "📋 Passo 8: Informações de conexão (sem TLS):"
echo "🔑 Para obter a senha do Redis:"
echo "   microk8s kubectl get secret --namespace redis redis-cluster -o jsonpath='{.data.redis-password}' | base64 -d"
echo ""
echo "🌐 Para conectar ao Redis:"
echo "   microk8s kubectl port-forward --namespace redis svc/redis-cluster-master 6379:6379 &"
echo "   redis-cli -h 127.0.0.1 -p 6379 -a \$(microk8s kubectl get secret --namespace redis redis-cluster -o jsonpath='{.data.redis-password}' | base64 -d)"
echo ""
echo "📈 Para acessar métricas:"
echo "   microk8s kubectl port-forward --namespace redis svc/redis-cluster-metrics 9121:9121 &"
echo "   curl http://127.0.0.1:9121/metrics"
echo ""
echo "⚠️  NOTA: TLS foi desabilitado temporariamente para debug"
echo "🎉 Instalação do Redis concluída com sucesso!"