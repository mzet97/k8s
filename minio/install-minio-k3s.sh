#!/bin/bash
set -e

# Script de instalação do MinIO para K3s
# Versão corrigida - 2025-12-11

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="minio"

echo "========================================="
echo "Instalação do MinIO no K3s"
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
echo "🔑 Criando secrets (credenciais)..."
if [ ! -f "$SCRIPT_DIR/01-secret.yaml" ]; then
    echo "⚠️  ATENÇÃO: Arquivo 01-secret.yaml não encontrado!"
    echo "   Crie o secret manualmente:"
    echo ""
    echo "   kubectl create secret generic minio-creds \\"
    echo "     --from-literal=rootUser=admin \\"
    echo "     --from-literal=rootPassword=\$(openssl rand -base64 32) \\"
    echo "     -n $NAMESPACE"
    echo ""
    read -p "Pressione ENTER para continuar após criar o secret..."
else
    kubectl apply -f "$SCRIPT_DIR/01-secret.yaml"
fi
echo ""

# 4. Criar certificados TLS
echo "🔒 Criando certificados TLS..."
kubectl apply -f "$SCRIPT_DIR/23-minio-console-certificate.yaml"
kubectl apply -f "$SCRIPT_DIR/24-minio-s3-certificate.yaml"

echo "   Aguardando certificados ficarem prontos..."
kubectl wait --for=condition=Ready certificate/minio-console-tls -n $NAMESPACE --timeout=120s || true
kubectl wait --for=condition=Ready certificate/minio-s3-tls -n $NAMESPACE --timeout=120s || true
echo ""

# 5. Criar services
echo "🌐 Criando services..."
kubectl apply -f "$SCRIPT_DIR/11-headless-svc.yaml"
kubectl apply -f "$SCRIPT_DIR/12-client-svc.yaml"
kubectl apply -f "$SCRIPT_DIR/20-minio-console-svc.yaml"
echo ""

# 6. Criar StatefulSet
echo "🗄️  Criando StatefulSet do MinIO..."
kubectl apply -f "$SCRIPT_DIR/20-statefulset.yaml"

echo "   Aguardando pod ficar pronto..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=minio -n $NAMESPACE --timeout=300s || true
echo ""

# 7. Criar Ingress
echo "🌍 Configurando Ingress (Traefik)..."
kubectl apply -f "$SCRIPT_DIR/21-minio-console-ingress.yaml"
kubectl apply -f "$SCRIPT_DIR/22-minio-s3-ingress.yaml"
echo ""

# 8. Verificar instalação
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

# 9. Obter informações de acesso
echo "========================================="
echo "✅ Instalação concluída!"
echo "========================================="
echo ""

TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")

echo "📝 Informações de Acesso:"
echo ""
echo "   Console MinIO: https://minio-console.home.arpa"
echo "   S3 API:        https://minio-s3.home.arpa"
echo ""
echo "   IP do Traefik: $TRAEFIK_IP"
echo ""

if [ "$TRAEFIK_IP" != "N/A" ]; then
    echo "📌 Configure seu DNS ou /etc/hosts:"
    echo ""
    echo "   echo '$TRAEFIK_IP minio-console.home.arpa' | sudo tee -a /etc/hosts"
    echo "   echo '$TRAEFIK_IP minio-s3.home.arpa' | sudo tee -a /etc/hosts"
    echo ""
fi

echo "🔑 Credenciais (Secret):"
echo ""
echo "   Usuário: admin"
echo "   Senha:   (definida em 01-secret.yaml)"
echo ""
echo "   Para ver a senha:"
echo "   kubectl get secret minio-creds -n $NAMESPACE -o jsonpath='{.data.rootPassword}' | base64 -d"
echo ""

echo "📚 Documentação: $SCRIPT_DIR/README.md"
echo ""
