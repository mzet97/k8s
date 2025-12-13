#!/usr/bin/env bash
set -euo pipefail

# Instala a stack ELK (Elasticsearch 3 nós, Kibana, Logstash, Filebeat)
# Pré-requisitos: kubectl, nginx-ingress, cert-manager com ClusterIssuer 'local-ca'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "[ELK] Aplicando Namespace e RBAC..."
kubectl apply -f 00-namespace.yaml
kubectl apply -f 03-rbac.yaml

echo "[ELK] Instalando Elasticsearch (ConfigMap, Services, NodePort, StatefulSet)..."
kubectl apply -f 10-elasticsearch-configmap.yaml
kubectl apply -f 11-headless-svc.yaml
kubectl apply -f 12-client-svc.yaml
kubectl apply -f 13-nodeport-svc.yaml
kubectl apply -f 20-elasticsearch-statefulset.yaml

echo "[ELK] Configurando Ingress/TLS para Elasticsearch..."
kubectl apply -f 15-elasticsearch-tls.yaml || true
kubectl apply -f 14-elasticsearch-ingress.yaml || true

echo "[ELK] Aguardando rollout do Elasticsearch..."
kubectl -n elk rollout status statefulset/elasticsearch --timeout=5m || true

echo "[ELK] Instalando Kibana (Service, NodePort, Deployment, TLS, Ingress)..."
kubectl apply -f 31-kibana-svc.yaml
kubectl apply -f 32-kibana-nodeport.yaml
kubectl apply -f 30-kibana-deployment.yaml

# Tenta criar certificado TLS (se cert-manager/local-ca existir)
kubectl apply -f 34-tls-certificates.yaml || true
kubectl apply -f 33-kibana-ingress.yaml

echo "[ELK] Aguardando rollout do Kibana..."
kubectl -n elk rollout status deployment/kibana --timeout=3m || true

echo "[ELK] Instalando Logstash (ConfigMap, Service, NodePort, Deployment)..."
kubectl apply -f 40-logstash-configmap.yaml
kubectl apply -f 42-logstash-svc.yaml
kubectl apply -f 43-logstash-nodeport.yaml
kubectl apply -f 41-logstash-deployment.yaml

echo "[ELK] Aguardando rollout do Logstash..."
kubectl -n elk rollout status deployment/logstash --timeout=3m || true

echo "[ELK] Instalando Filebeat (ConfigMap, DaemonSet)..."
kubectl apply -f 50-filebeat-configmap.yaml
kubectl apply -f 51-filebeat-daemonset.yaml

echo "[ELK] Aplicando NetworkPolicy..."
kubectl apply -f 60-network-policy.yaml

echo "[ELK] Recursos criados:"
kubectl -n elk get pods -o wide
kubectl -n elk get svc -o wide
kubectl -n elk get ingress

NODE_IP="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')"
echo "\n[ELK] Endpoints úteis:"
echo "- Elasticsearch NodePort:   http://$NODE_IP:30920"
echo "- Elasticsearch Ingress (TLS): https://elasticsearch.home.arpa (adicione em /etc/hosts se necessário)"
echo "- Kibana NodePort:          http://$NODE_IP:31601"
echo "- Kibana Ingress (TLS):     https://kibana.home.arpa (adicione em /etc/hosts se necessário)"
echo "- Logstash NodePort (beats): $NODE_IP:30044"

echo "\n[ELK] Testes rápidos:"
echo "curl -s http://elasticsearch.elk.svc.cluster.local:9200"
echo "curl -s http://$NODE_IP:30920"
echo "curl -Ik --resolve kibana.home.arpa:443:$NODE_IP https://kibana.home.arpa/"
echo "curl -s http://elasticsearch.elk.svc.cluster.local:9200/_cat/indices?v | grep logs- || true"

echo "\n[ELK] Instalação concluída."