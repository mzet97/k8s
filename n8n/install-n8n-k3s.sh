#!/bin/bash
set -e

# Script de instalação do n8n para K3s
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="n8n"

echo "========================================="
echo "Instalação do n8n no K3s"
echo "========================================="
echo ""

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não encontrado. Instale o kubectl primeiro."
    exit 1
fi

# 1. Criar namespace
echo "📁 Criando namespace '$NAMESPACE'..."
kubectl apply -f "$SCRIPT_DIR/00-namespace.yaml"
echo ""

# 2. Criar PVC
echo "💾 Criando volume persistente..."
kubectl apply -f "$SCRIPT_DIR/01-pvc.yaml"
echo ""

# 3. Criar services
echo "🌐 Criando services..."
kubectl apply -f "$SCRIPT_DIR/10-service.yaml"
echo ""

# 4. Criar Deployment
echo "🚀 Criando Deployment do n8n..."
kubectl apply -f "$SCRIPT_DIR/20-deployment.yaml"
echo ""

# 5. Criar Ingress e Certificado
echo "🔒 Configurando Ingress e HTTPS..."
kubectl apply -f "$SCRIPT_DIR/31-certificate.yaml"
kubectl apply -f "$SCRIPT_DIR/30-ingress.yaml"
echo ""

# 6. Aguardar pod
echo "⏳ Aguardando n8n iniciar..."
kubectl wait --for=condition=Ready pod -l app=n8n -n $NAMESPACE --timeout=300s || true
echo ""

# 7. Finalizar
echo "========================================="
echo "✅ Instalação concluída!"
echo "========================================="
echo ""

TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")

echo "📝 Informações de Acesso:"
echo ""
echo "   URL: https://n8n.home.arpa"
echo ""
echo "   IP do Cluster: $TRAEFIK_IP"
echo ""

if [ "$TRAEFIK_IP" != "N/A" ]; then
    echo "📌 Configure seu DNS ou /etc/hosts:"
    echo ""
    echo "   echo '$TRAEFIK_IP n8n.home.arpa' | sudo tee -a /etc/hosts"
    echo ""
fi
