#!/bin/bash
set -e

# Script de instalação do ELK Stack para K3s
# Versão corrigida - 2025-12-11
# Componentes: Elasticsearch, Logstash, Kibana, Filebeat

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="elk"

echo "========================================="
echo "Instalação do ELK Stack no K3s"
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

# 2. Criar secret de credenciais
echo "🔑 Criando credenciais do Elasticsearch..."
kubectl apply -f "$SCRIPT_DIR/01-elastic-credentials-secret.yaml"
echo ""

# 3. Aplicar RBAC
echo "🔐 Configurando RBAC..."
kubectl apply -f "$SCRIPT_DIR/03-rbac.yaml"
echo ""

# 4. Criar ConfigMaps
echo "📝 Criando ConfigMaps..."
kubectl apply -f "$SCRIPT_DIR/10-elasticsearch-configmap.yaml"
kubectl apply -f "$SCRIPT_DIR/40-logstash-configmap.yaml"
kubectl apply -f "$SCRIPT_DIR/50-filebeat-configmap.yaml"
echo ""

# 5. Criar certificados TLS
echo "🔒 Criando certificados TLS..."
kubectl apply -f "$SCRIPT_DIR/34-tls-certificates.yaml"

echo "   Aguardando certificados ficarem prontos..."
kubectl wait --for=condition=Ready certificate/elasticsearch-tls -n $NAMESPACE --timeout=120s || true
kubectl wait --for=condition=Ready certificate/kibana-tls -n $NAMESPACE --timeout=120s || true
echo ""

# 6. Criar services
echo "🌐 Criando services..."
kubectl apply -f "$SCRIPT_DIR/11-headless-svc.yaml"
kubectl apply -f "$SCRIPT_DIR/12-client-svc.yaml"
kubectl apply -f "$SCRIPT_DIR/31-kibana-svc.yaml"
kubectl apply -f "$SCRIPT_DIR/42-logstash-svc.yaml"
echo ""

# 7. Instalar Elasticsearch
echo "🔍 Instalando Elasticsearch (StatefulSet com 3 réplicas)..."
kubectl apply -f "$SCRIPT_DIR/20-elasticsearch-statefulset.yaml"

echo "   Aguardando Elasticsearch pods ficarem prontos..."
echo "   (Isso pode levar alguns minutos - Elasticsearch é pesado)"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=elasticsearch -n $NAMESPACE --timeout=600s || true
echo ""

# 8. Criar Ingress para Elasticsearch
echo "🌍 Configurando Ingress do Elasticsearch..."
kubectl apply -f "$SCRIPT_DIR/14-elasticsearch-ingress.yaml"
echo ""

# 9. Instalar Logstash
echo "📊 Instalando Logstash..."
kubectl apply -f "$SCRIPT_DIR/41-logstash-deployment.yaml"

echo "   Aguardando Logstash ficar pronto..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=logstash -n $NAMESPACE --timeout=300s || true
echo ""

# 10. Instalar Kibana
echo "📈 Instalando Kibana..."
kubectl apply -f "$SCRIPT_DIR/30-kibana-deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/33-kibana-ingress.yaml"

echo "   Aguardando Kibana ficar pronto..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=kibana -n $NAMESPACE --timeout=300s || true
echo ""

# 11. Instalar Filebeat (opcional)
echo "📋 Instalando Filebeat (DaemonSet)..."
kubectl apply -f "$SCRIPT_DIR/51-filebeat-daemonset.yaml"
echo ""

# 12. Verificar instalação
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

# 13. Verificar saúde do Elasticsearch
echo "🔍 Verificando saúde do cluster Elasticsearch..."
sleep 10  # Aguardar cluster estabilizar
kubectl exec -n $NAMESPACE elasticsearch-0 -- curl -s http://localhost:9200/_cluster/health?pretty || echo "⚠️  Cluster ainda inicializando..."
echo ""

# 14. Obter informações de acesso
echo "========================================="
echo "✅ Instalação concluída!"
echo "========================================="
echo ""

TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")

echo "📝 Informações de Acesso:"
echo ""
echo "   Kibana UI:         https://kibana.home.arpa"
echo "   Elasticsearch API: https://elasticsearch.home.arpa"
echo ""
echo "   🔐 Credenciais:"
echo "      Usuário: elastic"
echo "      Senha:   Admin@123"
echo ""
echo "   Elasticsearch interno: http://elasticsearch:9200"
echo "   Logstash (beats):      logstash:5044"
echo ""
echo "   IP do Traefik: $TRAEFIK_IP"
echo ""

if [ "$TRAEFIK_IP" != "N/A" ]; then
    echo "📌 Configure seu DNS ou /etc/hosts:"
    echo ""
    echo "   echo '$TRAEFIK_IP elasticsearch.home.arpa' | sudo tee -a /etc/hosts"
    echo "   echo '$TRAEFIK_IP kibana.home.arpa' | sudo tee -a /etc/hosts"
    echo ""
fi

echo "💾 Persistência:"
echo ""
echo "   ✅ Elasticsearch: 3x 50Gi PVCs (StorageClass: local-path)"
echo "   ✅ Dados seguros contra restarts"
echo ""

echo "📊 Componentes Instalados:"
echo ""
echo "   ✅ Elasticsearch 7.17.16 (3 réplicas)"
echo "   ✅ Kibana 7.17.16"
echo "   ✅ Logstash 7.17.16"
echo "   ✅ Filebeat (DaemonSet)"
echo ""

echo "🔍 Comandos Úteis:"
echo ""
echo "   # Ver índices do Elasticsearch"
echo "   kubectl exec -n $NAMESPACE elasticsearch-0 -- curl http://localhost:9200/_cat/indices?v"
echo ""
echo "   # Ver logs do Kibana"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=kibana -f"
echo ""
echo "   # Testar saúde do cluster"
echo "   kubectl exec -n $NAMESPACE elasticsearch-0 -- curl http://localhost:9200/_cluster/health?pretty"
echo ""

echo "📚 Documentação: $SCRIPT_DIR/README.md"
echo ""

echo "⚠️  IMPORTANTE:"
echo "   - Elasticsearch está configurado com 3 réplicas (cluster)"
echo "   - Cada réplica usa 50Gi de storage"
echo "   - Total de storage usado: ~150Gi"
echo "   - Ajuste storage em 20-elasticsearch-statefulset.yaml conforme necessário"
echo ""
