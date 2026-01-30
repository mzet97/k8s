#!/bin/bash

# Install Authentik on K3s
# Arquitetura: Server + Worker com PostgreSQL Externo e Redis Cluster Interno

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="authentik"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=========================================="
echo "Installing Authentik on K3s"
echo -e "==========================================${NC}"

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"
if ! kubectl get clusterissuer local-ca &>/dev/null; then
    echo -e "${RED}Error: ClusterIssuer 'local-ca' not found${NC}"
    exit 1
fi

if ! kubectl get namespace redis &>/dev/null; then
    echo -e "${YELLOW}Warning: Namespace 'redis' not found. Redis is required.${NC}"
fi

# Step 1: Namespace
echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl apply -f "$SCRIPT_DIR/00-namespace.yaml"

# Step 2: Secrets
echo -e "${BLUE}Step 2: Creating secrets...${NC}"
kubectl apply -f "$SCRIPT_DIR/01-secret.yaml"

# Step 3: PVC
echo -e "${BLUE}Step 3: Creating PVC...${NC}"
kubectl apply -f "$SCRIPT_DIR/02-pvc.yaml"

# Step 4: ConfigMap
echo -e "${BLUE}Step 4: Creating ConfigMap...${NC}"
kubectl apply -f "$SCRIPT_DIR/10-configmap.yaml"

# Step 5: Service
echo -e "${BLUE}Step 5: Creating service...${NC}"
kubectl apply -f "$SCRIPT_DIR/30-service.yaml"

# Step 6: Deployments
echo -e "${BLUE}Step 6: Deploying Authentik Server and Worker...${NC}"
kubectl apply -f "$SCRIPT_DIR/20-server-deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/21-worker-deployment.yaml"

# Step 7: Ingress
echo -e "${BLUE}Step 7: Creating ingress...${NC}"
kubectl apply -f "$SCRIPT_DIR/40-ingress.yaml"

echo ""
echo "Waiting for Authentik Server to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=authentik-server -n $NAMESPACE --timeout=300s || {
    echo -e "${YELLOW}Warning: Server pod not ready yet. Check logs: kubectl logs -n authentik -l app.kubernetes.io/name=authentik-server${NC}"
}

echo -e "${GREEN}=========================================="
echo "Installation Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Authentik is available at: https://authentik.home.arpa"
echo "Initial setup: Visit the URL above and follow the instructions."
echo ""
