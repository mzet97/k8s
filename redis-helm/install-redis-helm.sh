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

# Passo 3: Instalar cert-manager (se não estiver instalado)
echo "🔐 Passo 3: Verificando cert-manager..."
if ! microk8s kubectl get namespace cert-manager &> /dev/null; then
    echo "📦 Habilitando addon cert-manager no MicroK8s..."
    microk8s enable cert-manager
    
    echo "⏳ Aguardando cert-manager ficar pronto..."
    microk8s kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s
    microk8s kubectl wait --for=condition=ready pod -l app=cainjector -n cert-manager --timeout=300s
    microk8s kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=300s
    echo "✅ cert-manager instalado e pronto"
else
    echo "✅ cert-manager já está instalado"
fi

# Passo 4: Criar ClusterIssuer para TLS
echo "🔒 Passo 4: Configurando ClusterIssuer para TLS..."
cat <<EOF | microk8s kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: redis-tls-cert
  namespace: redis
spec:
  secretName: redis-tls-secret
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  commonName: redis.redis.svc.cluster.local
  dnsNames:
  - redis.redis.svc.cluster.local
  - redis-master.redis.svc.cluster.local
  - redis-replica.redis.svc.cluster.local
  - "*.redis.svc.cluster.local"
  - "*.redis-headless.redis.svc.cluster.local"
EOF
echo "✅ ClusterIssuer e Certificate configurados"

# Passo 5: Aguardar certificado TLS
echo "⏳ Passo 5: Aguardando certificado TLS ser criado..."
microk8s kubectl wait --for=condition=ready certificate redis-tls-cert -n redis --timeout=300s
echo "✅ Certificado TLS criado com sucesso"

# Passo 6: Instalar Redis com Helm
echo "🚀 Passo 6: Instalando Redis com Helm..."
microk8s helm3 upgrade --install redis-cluster bitnami/redis \
  --namespace redis \
  --values values.yaml \
  --set tls.existingSecret=redis-tls-secret \
  --set tls.certFilename=tls.crt \
  --set tls.certKeyFilename=tls.key \
  --set tls.certCAFilename=ca.crt \
  --wait --timeout=600s

echo "✅ Redis instalado com sucesso!"

# Passo 7: Aguardar pods ficarem prontos
echo "⏳ Passo 7: Aguardando pods Redis ficarem prontos..."
microk8s kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n redis --timeout=300s
echo "✅ Todos os pods Redis estão prontos"

# Passo 8: Aplicar HPA (Horizontal Pod Autoscaler)
echo "📈 Passo 8: Configurando HPA para replicas..."
microk8s kubectl apply -f hpa-config.yaml
echo "✅ HPA configurado para autoscaling das replicas"

# Passo 9: Verificar status da instalação
echo "🔍 Passo 9: Verificando status da instalação..."
echo ""
echo "📊 Status dos Pods:"
microk8s kubectl get pods -n redis -o wide
echo ""
echo "🌐 Services:"
microk8s kubectl get svc -n redis
echo ""
echo "🔐 Secrets:"
microk8s kubectl get secrets -n redis
echo ""
echo "📜 Certificados:"
microk8s kubectl get certificates -n redis
echo ""
echo "📈 HPA Status:"
microk8s kubectl get hpa -n redis
echo ""

# Passo 10: Obter informações de conexão
echo "📋 Passo 10: Informações de conexão:"
echo ""
echo "🔑 Para obter a senha do Redis:"
echo "microk8s kubectl get secret redis-cluster -n redis -o jsonpath='{.data.redis-password}' | base64 -d"
echo ""
echo "🔗 Para conectar ao Redis Master:"
echo "microk8s kubectl run redis-client --rm -it --restart=Never --namespace redis --image docker.io/bitnami/redis:7.2.4-debian-11-r0 -- bash"
echo "Dentro do pod:"
echo "REDISCLI_AUTH=\$(microk8s kubectl get secret redis-cluster -n redis -o jsonpath='{.data.redis-password}' | base64 -d)"
echo "redis-cli -h redis-cluster-master.redis.svc.cluster.local -p 6379 --tls --cert /etc/ssl/certs/redis.crt --key /etc/ssl/private/redis.key --cacert /etc/ssl/certs/ca.crt"
echo ""
echo "🔗 Para conectar às Replicas:"
echo "redis-cli -h redis-cluster-replica.redis.svc.cluster.local -p 6379 --tls --cert /etc/ssl/certs/redis.crt --key /etc/ssl/private/redis.key --cacert /etc/ssl/certs/ca.crt"
echo ""
echo "📊 Para monitorar métricas:"
echo "microk8s kubectl port-forward svc/redis-cluster-metrics 9121:9121 -n redis"
echo "Acesse: http://localhost:9121/metrics"
echo ""
echo "🎉 Instalação concluída com sucesso!"
echo "   - 1 Master Redis"
echo "   - 3 Replicas Redis"
echo "   - TLS habilitado"
echo "   - DNS configurado"
echo "   - Métricas habilitadas"
echo "   - Persistência habilitada"