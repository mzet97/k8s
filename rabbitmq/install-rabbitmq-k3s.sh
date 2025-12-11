#!/bin/bash
set -e

# Script de instalação do RabbitMQ para K3s
# Versão corrigida - 2025-12-11

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="rabbitmq"

echo "========================================="
echo "Instalação do RabbitMQ no K3s"
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

# 2. Aplicar RBAC
echo "🔐 Configurando RBAC..."
kubectl apply -f "$SCRIPT_DIR/03-rbac.yaml"
echo ""

# 3. Criar secrets
echo "🔑 Criando secrets..."
if [ ! -f "$SCRIPT_DIR/01-secret.yaml" ]; then
    echo "⚠️  ATENÇÃO: Arquivo 01-secret.yaml não encontrado!"
    echo "   Crie o secret manualmente:"
    echo ""
    RANDOM_PASSWORD=$(openssl rand -base64 32)
    RANDOM_COOKIE=$(openssl rand -base64 32)
    echo "   kubectl create secret generic rabbitmq-admin \\"
    echo "     --from-literal=username=admin \\"
    echo "     --from-literal=password=$RANDOM_PASSWORD \\"
    echo "     --from-literal=cookie=$RANDOM_COOKIE \\"
    echo "     -n $NAMESPACE"
    echo ""
    read -p "Pressione ENTER para continuar após criar o secret..."
else
    kubectl apply -f "$SCRIPT_DIR/01-secret.yaml"
fi
echo ""

# 4. Criar ConfigMap
echo "📝 Criando ConfigMap..."
kubectl apply -f "$SCRIPT_DIR/10-configmap.yaml"
echo ""

# 5. Criar certificados TLS
echo "🔒 Criando certificados TLS..."
kubectl apply -f "$SCRIPT_DIR/02-tls-certificates.yaml"

echo "   Aguardando certificados ficarem prontos..."
kubectl wait --for=condition=Ready certificate/rabbitmq-tls -n $NAMESPACE --timeout=120s || true
kubectl wait --for=condition=Ready certificate/rabbitmq-management-tls -n $NAMESPACE --timeout=120s || true
echo ""

# 6. Criar services
echo "🌐 Criando services..."
kubectl apply -f "$SCRIPT_DIR/11-headless-svc.yaml"
kubectl apply -f "$SCRIPT_DIR/12-client-svc.yaml"
kubectl apply -f "$SCRIPT_DIR/13-management-svc.yaml"
echo ""

# 7. Criar StatefulSet
echo "🐰 Criando StatefulSet do RabbitMQ..."
kubectl apply -f "$SCRIPT_DIR/20-statefulset.yaml"

echo "   Aguardando pod ficar pronto..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=rabbitmq -n $NAMESPACE --timeout=300s || true
echo ""

# 8. Criar Ingress
echo "🌍 Configurando Ingress (Traefik)..."
kubectl apply -f "$SCRIPT_DIR/30-management-ingress.yaml"
echo ""

# 9. Verificar instalação
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

echo "🔒 Certificados:"
kubectl get certificate -n $NAMESPACE
echo ""

echo "🌍 Ingress:"
kubectl get ingress -n $NAMESPACE
echo ""

# 10. Obter informações de acesso
echo "========================================="
echo "✅ Instalação concluída!"
echo "========================================="
echo ""

TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")

echo "📝 Informações de Acesso:"
echo ""
echo "   Management UI: https://rabbitmq-mgmt.home.arpa"
echo "   AMQP:          rabbitmq.rabbitmq.svc.cluster.local:5672"
echo "   AMQPS:         rabbitmq.rabbitmq.svc.cluster.local:5671"
echo ""
echo "   IP do Traefik: $TRAEFIK_IP"
echo ""

if [ "$TRAEFIK_IP" != "N/A" ]; then
    echo "📌 Configure seu DNS ou /etc/hosts:"
    echo ""
    echo "   echo '$TRAEFIK_IP rabbitmq-mgmt.home.arpa' | sudo tee -a /etc/hosts"
    echo ""
fi

echo "🔑 Credenciais (Secret):"
echo ""
echo "   Usuário: admin"
echo "   Senha:   (definida em 01-secret.yaml)"
echo ""
echo "   Para ver a senha:"
echo "   kubectl get secret rabbitmq-admin -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d"
echo ""

echo "💾 Persistência:"
echo ""
echo "   ✅ Dados persistidos em PersistentVolumeClaims"
echo "   ✅ StorageClass: local-path (K3s)"
echo "   ✅ Dados: 10Gi, Logs: 2Gi"
echo ""

echo "📚 Documentação: $SCRIPT_DIR/README.md"
echo ""
