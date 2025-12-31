#!/bin/bash
set -e

# Script de instalação do NATS para K3s
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="nats"

echo "========================================="
echo "Instalação do NATS no K3s"
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

# 2. Criar ConfigMap e Secret
echo "⚙️  Configurando NATS..."
kubectl apply -f "$SCRIPT_DIR/01-secret.yaml"
kubectl apply -f "$SCRIPT_DIR/02-config.yaml"
echo ""

# 3. Criar PVC
echo "💾 Criando volume persistente (JetStream)..."
kubectl apply -f "$SCRIPT_DIR/03-pvc.yaml"
echo ""

# 4. Criar services
echo "🌐 Criando services..."
kubectl apply -f "$SCRIPT_DIR/10-service.yaml"
kubectl apply -f "$SCRIPT_DIR/11-loadbalancer.yaml"
echo ""

# 5. Criar StatefulSet
echo "🚀 Criando StatefulSet do NATS..."
kubectl apply -f "$SCRIPT_DIR/20-statefulset.yaml"
echo ""

# 6. Criar Ingress e Certificado (Monitor)
echo "🔒 Configurando Monitoramento HTTPS..."
kubectl apply -f "$SCRIPT_DIR/31-certificate.yaml"
kubectl apply -f "$SCRIPT_DIR/30-ingress.yaml"
echo ""

# 7. Aguardar pod
echo "⏳ Aguardando NATS iniciar..."
kubectl wait --for=condition=Ready pod -l app=nats -n $NAMESPACE --timeout=300s || true
echo ""

# 8. Finalizar
echo "========================================="
echo "✅ Instalação concluída!"
echo "========================================="
echo ""

TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")

echo "📝 Informações de Acesso:"
echo ""
echo "   NATS Server (TCP):  nats.home.arpa:4222"
echo "   NATS Monitor (Web): https://nats-monitor.home.arpa"
echo ""
echo "   IP do Cluster:      $TRAEFIK_IP"
echo ""

if [ "$TRAEFIK_IP" != "N/A" ]; then
    echo "📌 Configure seu DNS ou /etc/hosts:"
    echo ""
    echo "   # Adicione as seguintes linhas ao seu arquivo hosts:"
    echo "   echo '$TRAEFIK_IP nats-monitor.home.arpa' | sudo tee -a /etc/hosts"
    echo "   echo '$TRAEFIK_IP nats.home.arpa' | sudo tee -a /etc/hosts"
    echo ""
fi
