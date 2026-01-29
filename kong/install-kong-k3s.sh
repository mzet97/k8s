#!/bin/bash

# Install Kong Gateway on K3s (DB-less mode)
# Baseado no padrão SRE do repositório

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="kong"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=========================================="
echo "Installing Kong Gateway on K3s"
echo -e "==========================================${NC}"

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"
if ! kubectl get clusterissuer local-ca &>/dev/null; then
    echo -e "${RED}Error: ClusterIssuer 'local-ca' not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Prerequisites met${NC}"

# Step 1: Namespace
echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl apply -f "$SCRIPT_DIR/00-namespace.yaml"

# Step 2: Secrets
echo -e "${BLUE}Step 2: Creating secrets...${NC}"
kubectl apply -f "$SCRIPT_DIR/01-secret.yaml"

# Step 3: TLS Certificates
echo -e "${BLUE}Step 3: Creating TLS certificates...${NC}"
kubectl apply -f "$SCRIPT_DIR/02-tls-certificates.yaml"

# Step 4: RBAC
echo -e "${BLUE}Step 4: Configuring RBAC...${NC}"
kubectl apply -f "$SCRIPT_DIR/03-rbac.yaml"

# Step 5: ConfigMap
echo -e "${BLUE}Step 5: Creating ConfigMap...${NC}"
kubectl apply -f "$SCRIPT_DIR/10-configmap.yaml"

# Step 6: Deployment & Services
echo -e "${BLUE}Step 6: Deploying Kong Gateway...${NC}"
kubectl apply -f "$SCRIPT_DIR/20-kong-deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/30-services.yaml"
kubectl apply -f "$SCRIPT_DIR/40-ingress.yaml"

echo "Waiting for Kong to be ready..."
kubectl wait --for=condition=ready pod -l app=kong -n $NAMESPACE --timeout=120s

echo -e "${GREEN}=========================================="
echo "Installation Complete!"
echo -e "==========================================${NC}"
echo "User: admin"
echo "Password: Admin@123"
echo ""
echo "Access URLs:"
echo "  Proxy: http://<EXTERNAL_IP>:80"
echo "  Admin API (External): https://kong-admin.local"
echo ""
echo "Check ACESSO_KONG.md for more details."
