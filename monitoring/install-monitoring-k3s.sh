#!/bin/bash
set -e

# Script de instalação do Stack de Monitoring para K3s
# Versão corrigida - 2025-12-11
# Componentes: Prometheus, Grafana, Loki, Node Exporter, Kube State Metrics

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="monitoring"

echo "========================================="
echo "Instalação do Monitoring Stack no K3s"
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

# 2. Configurar RBAC Prometheus
echo "🔐 Configurando RBAC..."
kubectl apply -f "$SCRIPT_DIR/10-prometheus-rbac.yaml"
echo ""

# 3. Criar secrets
echo "🔑 Criando secrets..."
if [ ! -f "$SCRIPT_DIR/01-grafana-admin-secret.yaml" ]; then
    echo "⚠️  ATENÇÃO: Arquivo 01-grafana-admin-secret.yaml não encontrado!"
    echo "   Crie o secret manualmente:"
    echo ""
    RANDOM_PASSWORD=$(openssl rand -base64 16)
    echo "   kubectl create secret generic grafana-admin \\"
    echo "     --from-literal=GF_SECURITY_ADMIN_USER=admin \\"
    echo "     --from-literal=GF_SECURITY_ADMIN_PASSWORD=$RANDOM_PASSWORD \\"
    echo "     -n $NAMESPACE"
    echo ""
    read -p "Pressione ENTER para continuar após criar o secret..."
else
    kubectl apply -f "$SCRIPT_DIR/01-grafana-admin-secret.yaml"
fi
echo ""

# 4. Criar ConfigMaps
echo "📝 Criando ConfigMaps..."
kubectl apply -f "$SCRIPT_DIR/11-prometheus-config.yaml"
kubectl apply -f "$SCRIPT_DIR/02-grafana-config-datasource.yaml"
echo ""

# 5. Criar certificados TLS
echo "🔒 Criando certificados TLS..."
kubectl apply -f "$SCRIPT_DIR/42-prometheus-certificate.yaml"
kubectl apply -f "$SCRIPT_DIR/32-grafana-certificate.yaml"

echo "   Aguardando certificados ficarem prontos..."
kubectl wait --for=condition=Ready certificate/prometheus-tls -n $NAMESPACE --timeout=120s || true
kubectl wait --for=condition=Ready certificate/grafana-tls -n $NAMESPACE --timeout=120s || true
echo ""

# 6. Instalar Node Exporter (coleta métricas dos nodes)
echo "📊 Instalando Node Exporter (DaemonSet)..."
kubectl apply -f "$SCRIPT_DIR/20-node-exporter-daemonset.yaml"
echo ""

# 7. Instalar Kube State Metrics (métricas do cluster)
echo "📊 Instalando Kube State Metrics..."
kubectl apply -f "$SCRIPT_DIR/21-kube-state-metrics.yaml"
echo ""

# 8. Instalar Prometheus
echo "🔍 Instalando Prometheus..."
kubectl apply -f "$SCRIPT_DIR/12-prometheus-statefulset.yaml"
kubectl apply -f "$SCRIPT_DIR/40-prometheus-service.yaml"
kubectl apply -f "$SCRIPT_DIR/41-prometheus-ingress.yaml"

echo "   Aguardando Prometheus ficar pronto..."
kubectl wait --for=condition=Ready pod -l app=prometheus -n $NAMESPACE --timeout=300s || true
echo ""

# 9. Instalar Loki (agregação de logs)
echo "📋 Instalando Loki..."
kubectl apply -f "$SCRIPT_DIR/50-loki-config.yaml"

echo "   Aguardando Loki ficar pronto..."
kubectl wait --for=condition=Ready pod -l app=loki -n $NAMESPACE --timeout=300s || true
echo ""

# 10. Instalar Grafana
echo "📈 Instalando Grafana..."
kubectl apply -f "$SCRIPT_DIR/30-grafana-deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/31-grafana-ingress.yaml"

echo "   Aguardando Grafana ficar pronto..."
kubectl wait --for=condition=Ready pod -l app=grafana -n $NAMESPACE --timeout=300s || true
echo ""

# 11. Verificar instalação
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

echo "💾 PVCs:"
kubectl get pvc -n $NAMESPACE
echo ""

# 12. Obter informações de acesso
echo "========================================="
echo "✅ Instalação concluída!"
echo "========================================="
echo ""

TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")

echo "📝 Informações de Acesso:"
echo ""
echo "   Prometheus: https://prometheus.home.arpa"
echo "   Grafana:    https://grafana.home.arpa"
echo "   Loki:       loki.monitoring.svc.cluster.local:3100 (interno)"
echo ""
echo "   IP do Traefik: $TRAEFIK_IP"
echo ""

if [ "$TRAEFIK_IP" != "N/A" ]; then
    echo "📌 Configure seu DNS ou /etc/hosts:"
    echo ""
    echo "   echo '$TRAEFIK_IP prometheus.home.arpa' | sudo tee -a /etc/hosts"
    echo "   echo '$TRAEFIK_IP grafana.home.arpa' | sudo tee -a /etc/hosts"
    echo ""
fi

echo "🔑 Credenciais Grafana:"
echo ""
echo "   Usuário: admin"
echo "   Senha:   (definida em 01-grafana-admin-secret.yaml)"
echo ""
echo "   Para ver a senha:"
echo "   kubectl get secret grafana-admin -n $NAMESPACE -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d"
echo ""

echo "💾 Persistência:"
echo ""
echo "   ✅ Prometheus: 20Gi (StorageClass: local-path)"
echo "   ✅ Grafana: 10Gi (StorageClass: local-path)"
echo "   ✅ Loki: 10Gi (StorageClass: local-path)"
echo ""

echo "📊 Componentes Instalados:"
echo ""
echo "   ✅ Prometheus (métricas)"
echo "   ✅ Grafana (dashboards)"
echo "   ✅ Loki (logs)"
echo "   ✅ Node Exporter (métricas de nodes)"
echo "   ✅ Kube State Metrics (métricas do cluster)"
echo ""

echo "📚 Documentação: $SCRIPT_DIR/README.md"
echo ""
