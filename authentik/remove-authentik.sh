#!/bin/bash

# Remove Authentik from K3s

set -e

# Colors
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="authentik"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${RED}=========================================="
echo "Removing Authentik from K3s"
echo -e "==========================================${NC}"

kubectl delete -f "$SCRIPT_DIR/40-ingress.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/30-service.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/21-worker-deployment.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/20-server-deployment.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/10-configmap.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/02-pvc.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/01-secret.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/00-namespace.yaml" --ignore-not-found

echo ""
echo -e "${RED}Authentik has been removed.${NC}"
