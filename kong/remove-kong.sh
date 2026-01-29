#!/bin/bash

# Remove Kong Gateway from K3s

NAMESPACE="kong"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Removing Kong Gateway..."

kubectl delete -f "$SCRIPT_DIR/40-ingress.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/30-services.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/20-kong-deployment.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/10-configmap.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/03-rbac.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/02-tls-certificates.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/01-secret.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/00-namespace.yaml" --ignore-not-found

echo "Kong Gateway removed successfully."
