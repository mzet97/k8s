#!/bin/bash

# Install cert-manager on K3s
# This script installs cert-manager and configures ClusterIssuers for local development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# cert-manager version
CERT_MANAGER_VERSION=${CERT_MANAGER_VERSION:-v1.16.2}

echo -e "${BLUE}=========================================="
echo "Installing cert-manager ${CERT_MANAGER_VERSION}"
echo -e "==========================================${NC}"
echo ""

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-120}

    echo -e "${YELLOW}Waiting for deployment ${deployment} in namespace ${namespace}...${NC}"

    kubectl wait --for=condition=available \
        --timeout=${timeout}s \
        deployment/${deployment} \
        -n ${namespace} 2>/dev/null || {
        echo -e "${YELLOW}Warning: Deployment ${deployment} not ready after ${timeout}s${NC}"
        return 1
    }

    echo -e "${GREEN}✓ Deployment ${deployment} is ready${NC}"
    return 0
}

# Step 1: Install cert-manager CRDs
echo -e "${BLUE}Step 1: Installing cert-manager CRDs...${NC}"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ CRDs installed successfully${NC}"
else
    echo -e "${RED}✗ Failed to install CRDs${NC}"
    exit 1
fi

echo ""

# Step 2: Install cert-manager
echo -e "${BLUE}Step 2: Installing cert-manager...${NC}"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ cert-manager manifests applied${NC}"
else
    echo -e "${RED}✗ Failed to apply cert-manager manifests${NC}"
    exit 1
fi

echo ""

# Step 3: Wait for cert-manager to be ready
echo -e "${BLUE}Step 3: Waiting for cert-manager to be ready...${NC}"
echo "This may take a few minutes..."
echo ""

# Wait for namespace to be created
echo "Waiting for cert-manager namespace..."
for i in {1..30}; do
    if kubectl get namespace cert-manager >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Namespace cert-manager exists${NC}"
        break
    fi
    sleep 2
done

# Wait for deployments
wait_for_deployment cert-manager cert-manager 120
wait_for_deployment cert-manager cert-manager-webhook 120
wait_for_deployment cert-manager cert-manager-cainjector 120

echo ""

# Step 4: Verify installation
echo -e "${BLUE}Step 4: Verifying cert-manager installation...${NC}"

echo "Checking cert-manager pods..."
kubectl get pods -n cert-manager

echo ""
echo "Checking cert-manager version..."
kubectl get deployment -n cert-manager cert-manager -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

echo ""

# Step 5: Install ClusterIssuers
echo -e "${BLUE}Step 5: Installing ClusterIssuers...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/00-cert-manager-issuers.yaml" ]; then
    echo "Applying ClusterIssuers from 00-cert-manager-issuers.yaml..."
    kubectl apply -f "$SCRIPT_DIR/00-cert-manager-issuers.yaml"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ClusterIssuers installed${NC}"
    else
        echo -e "${YELLOW}Warning: Failed to install ClusterIssuers${NC}"
    fi
else
    echo -e "${YELLOW}Warning: 00-cert-manager-issuers.yaml not found${NC}"
    echo "You can apply it manually later."
fi

echo ""

# Step 6: Wait for ClusterIssuers to be ready
echo -e "${BLUE}Step 6: Checking ClusterIssuers status...${NC}"
sleep 5

kubectl get clusterissuer 2>/dev/null || echo "No ClusterIssuers found yet"

echo ""

# Summary
echo -e "${GREEN}=========================================="
echo "cert-manager Installation Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Installed components:"
echo "  • cert-manager controller"
echo "  • cert-manager webhook"
echo "  • cert-manager cainjector"
echo ""
echo "ClusterIssuers available:"
kubectl get clusterissuer -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,AGE:.metadata.creationTimestamp 2>/dev/null || echo "  (none yet - apply 00-cert-manager-issuers.yaml)"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n cert-manager"
echo "  kubectl get clusterissuer"
echo "  kubectl get certificate -A"
echo "  kubectl describe clusterissuer <name>"
echo ""
echo "Next steps:"
echo "  1. Review and apply ClusterIssuers if not already done"
echo "  2. Create Certificate resources for your applications"
echo "  3. Configure Ingress/IngressRoute to use TLS"
echo ""
echo "Documentation:"
echo "  • README.md - How to use cert-manager"
echo "  • https://cert-manager.io/docs/"
echo ""
