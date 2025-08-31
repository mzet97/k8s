#!/bin/bash

# Script de Instalação do Redis Master-Replica no Kubernetes
# Baseado na documentação do README.md
# Executa os comandos na ordem correta para instalação completa

set -e  # Parar execução em caso de erro

echo "🚀 Iniciando instalação do Redis Master-Replica no Kubernetes..."
echo ""

# Verificar se microk8s está disponível
if ! command -v microk8s &> /dev/null; then
    echo "❌ Erro: microk8s não encontrado. Instale o MicroK8s primeiro."
    exit 1
fi

echo "📋 Pré-requisitos verificados"
echo ""

# 1. Criar namespace e configurações básicas
echo "1️⃣ Criando namespace e configurações básicas..."
microk8s kubectl apply -f 00-namespace.yaml
microk8s kubectl apply -f 01-secret.yaml
microk8s kubectl apply -f 03-rbac.yaml
echo "✅ Namespace e configurações básicas criadas"
echo ""

# 2. Configurar TLS e certificados
echo "2️⃣ Configurando TLS e certificados..."
microk8s kubectl apply -f 02-tls-certificates.yaml
echo "✅ Certificados TLS configurados"
echo ""

# Aguardar certificados serem criados
echo "⏳ Aguardando certificados serem criados..."
sleep 10
microk8s kubectl -n redis get certificates
echo ""

# 3. Configurar Redis (ConfigMaps e Services)
echo "3️⃣ Configurando Redis (ConfigMaps e Services)..."
microk8s kubectl apply -f 10-configmap.yaml
microk8s kubectl apply -f 11-headless-svc.yaml
microk8s kubectl apply -f 12-client-svc.yaml
microk8s kubectl apply -f 13-master-svc.yaml
echo "✅ ConfigMaps e Services configurados"
echo ""

# 4. Implantar Redis Master e Réplicas
echo "4️⃣ Implantando Redis Master e Réplicas..."
microk8s kubectl apply -f 21-master-statefulset.yaml
microk8s kubectl apply -f 22-replica-statefulset.yaml
echo "✅ Redis Master e Réplicas implantados"
echo ""

# Aguardar pods estarem prontos
echo "⏳ Aguardando pods estarem prontos..."
sleep 30
microk8s kubectl -n redis get pods
echo ""

# 5. Configurar replicação
echo "5️⃣ Configurando replicação..."
microk8s kubectl apply -f 31-replication-setup-job.yaml
echo "✅ Replicação configurada"
echo ""

# 6. Configurar acesso externo
echo "6️⃣ Configurando acesso externo..."
microk8s kubectl apply -f 42-redis-proxy-tls.yaml
microk8s kubectl apply -f 43-dns-config.yaml
echo "✅ Acesso externo configurado"
echo ""

# 7. Configurar monitoramento e backup (opcional)
echo "7️⃣ Configurando monitoramento e backup (opcional)..."
microk8s kubectl apply -f 50-backup-cronjob.yaml
microk8s kubectl apply -f 60-monitoring.yaml
microk8s kubectl apply -f 70-high-availability.yaml
echo "✅ Monitoramento e backup configurados"
echo ""

# Verificação da instalação
echo "🔍 Verificando instalação..."
echo ""

echo "📊 Status dos pods:"
microk8s kubectl -n redis get pods
echo ""

echo "🌐 Serviços disponíveis:"
microk8s kubectl -n redis get svc
echo ""

echo "🔐 Certificados TLS:"
microk8s kubectl -n redis get certificates
echo ""

# Obter IP do nó para configuração DNS
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "📡 IP do nó Kubernetes: $NODE_IP"
echo ""

echo "🎉 Instalação concluída com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo "1. Configure o DNS local adicionando ao arquivo hosts:"
echo "   $NODE_IP redis.home.arpa"
echo "   $NODE_IP redis-proxy.home.arpa"
echo ""
echo "2. Teste a conectividade:"
echo "   redis-cli -h redis.home.arpa -p 30379 -a Admin@123 ping"
echo ""
echo "3. Acesse o dashboard HAProxy:"
echo "   http://redis.home.arpa:30404/stats (admin/admin123)"
echo ""
echo "📚 Consulte o README.md para mais informações sobre testes e uso."