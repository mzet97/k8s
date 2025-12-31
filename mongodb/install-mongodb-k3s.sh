#!/bin/bash
set -e

# Script de instalação do MongoDB para K3s
# Baseado na configuração do MinIO

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="mongodb"

echo "========================================="
echo "Instalação do MongoDB no K3s"
echo "========================================="
echo ""

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não encontrado. Instale o kubectl primeiro."
    exit 1
fi

# Verificar se cluster está acessível
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Não foi possível conectar ao cluster Kubernetes."
    exit 1
fi

echo "✅ Cluster K3s acessível"
echo ""

# 1. Criar namespace
echo "📁 Criando namespace '$NAMESPACE'..."
kubectl apply -f "$SCRIPT_DIR/00-namespace.yaml"
echo ""

# 2. Criar secrets
echo "🔑 Criando secrets (credenciais)..."
if [ ! -f "$SCRIPT_DIR/01-secret.yaml" ]; then
    echo "⚠️  ATENÇÃO: Arquivo 01-secret.yaml não encontrado!"
    echo "   Crie o secret manualmente:"
    echo "   kubectl create secret generic mongodb-creds --from-literal=mongo-root-username=admin --from-literal=mongo-root-password=password -n $NAMESPACE"
else
    kubectl apply -f "$SCRIPT_DIR/01-secret.yaml"
fi
echo ""

# 3. Criar services
echo "🌐 Criando services..."
kubectl apply -f "$SCRIPT_DIR/11-headless-svc.yaml"
kubectl apply -f "$SCRIPT_DIR/12-client-svc.yaml"
echo ""

# 4. Criar StatefulSet
echo "🗄️  Criando StatefulSet do MongoDB..."
kubectl apply -f "$SCRIPT_DIR/20-statefulset.yaml"

echo "   Aguardando pod ficar pronto..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=mongodb -n $NAMESPACE --timeout=300s || true
echo ""

# 5. Criar Mongo Express (Console Web)
echo "🌐 Configurando Mongo Express (Console)..."
kubectl apply -f "$SCRIPT_DIR/30-mongo-express.yaml"
echo ""

# 6. Verificar instalação
echo "========================================="
echo "Verificando instalação..."
echo "========================================="
echo ""

echo "📊 Pods:"
kubectl get pods -n $NAMESPACE
echo ""

echo "🌐 Services:"
kubectl get svc -n $NAMESPACE
echo ""

# 7. Obter informações de acesso
echo "========================================="
echo "✅ Instalação concluída!"
echo "========================================="
echo ""

TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")

echo "📝 Informações de Acesso:"
echo ""
echo "   Mongo Express:     https://mongodb-console.home.arpa"
echo "   MongoDB (Externo): mongodb://admin:Admin%40123@mongodb.home.arpa:27017/?authSource=admin"
echo "   Service (Interno): mongodb-client.$NAMESPACE.svc.cluster.local"
echo ""
echo "   IP do Cluster:     $TRAEFIK_IP"
echo ""

if [ "$TRAEFIK_IP" != "N/A" ]; then
    echo "📌 Configure seu DNS ou /etc/hosts:"
    echo ""
    echo "   # Adicione as seguintes linhas ao seu arquivo hosts:"
    echo "   echo '$TRAEFIK_IP mongodb-console.home.arpa' | sudo tee -a /etc/hosts"
    echo "   echo '$TRAEFIK_IP mongodb.home.arpa' | sudo tee -a /etc/hosts"
    echo ""
fi
echo "🔑 Credenciais (Secret):"
echo ""
echo "   Usuário: admin"
echo "   Senha:   (definida em 01-secret.yaml)"
echo ""
echo "   Para ver a senha:"
echo "   kubectl get secret mongodb-creds -n $NAMESPACE -o jsonpath='{.data.mongo-root-password}' | base64 -d"
echo ""
