#!/usr/bin/env bash
set -euo pipefail

# Remove a stack ELK por completo

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "[ELK] Removendo Filebeat e RBAC..."
kubectl delete -n elk -f 51-filebeat-daemonset.yaml -f 50-filebeat-configmap.yaml -f 03-rbac.yaml || true

echo "[ELK] Removendo Logstash..."
kubectl delete -n elk -f 41-logstash-deployment.yaml -f 43-logstash-nodeport.yaml -f 42-logstash-svc.yaml -f 40-logstash-configmap.yaml || true

echo "[ELK] Removendo Kibana (Deployment, Services, Ingress, TLS)..."
kubectl delete -n elk -f 30-kibana-deployment.yaml -f 32-kibana-nodeport.yaml -f 31-kibana-svc.yaml -f 33-kibana-ingress.yaml -f 34-tls-certificates.yaml || true

echo "[ELK] Removendo Elasticsearch..."
kubectl delete -n elk -f 14-elasticsearch-ingress.yaml -f 15-elasticsearch-tls.yaml || true
kubectl delete -n elk -f 20-elasticsearch-statefulset.yaml -f 13-nodeport-svc.yaml -f 12-client-svc.yaml -f 11-headless-svc.yaml -f 10-elasticsearch-configmap.yaml || true

echo "[ELK] Removendo Namespace..."
kubectl delete namespace elk || true

echo "[ELK] Remoção concluída."