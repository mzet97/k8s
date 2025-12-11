#!/bin/bash

# Install Redis Master-Replica on K3s
# Arquitetura: 1 Master + 3 Replicas com TLS e ServiceLB

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="redis"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=========================================="
echo "Installing Redis Master-Replica on K3s"
echo -e "==========================================${NC}"
echo ""
echo "Architecture:"
echo "  • 1 Master (StatefulSet)"
echo "  • 3 Replicas (StatefulSet)"
echo "  • TLS enabled (port 6380)"
echo "  • Non-TLS (port 6379)"
echo "  • ServiceLB for external access"
echo "  • Storage: local-path (K3s)"
echo ""

# Check if cert-manager is installed
echo -e "${BLUE}Checking prerequisites...${NC}"
if ! kubectl get clusterissuer local-ca &>/dev/null; then
    echo -e "${RED}Error: ClusterIssuer 'local-ca' not found${NC}"
    echo "Please install cert-manager first:"
    echo "  cd ~/k8s/certs && ./install-cert-manager.sh"
    exit 1
fi
echo -e "${GREEN}✓ cert-manager is installed${NC}"

# Check if local-path StorageClass exists
if ! kubectl get storageclass local-path &>/dev/null; then
    echo -e "${YELLOW}Warning: StorageClass 'local-path' not found${NC}"
    echo "K3s should have this by default. Checking..."
    kubectl get storageclass
fi

echo ""

# Step 1: Namespace
echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl apply -f "$SCRIPT_DIR/00-namespace.yaml"
echo ""

# Step 2: Secrets
echo -e "${BLUE}Step 2: Creating secrets...${NC}"
kubectl apply -f "$SCRIPT_DIR/01-secret.yaml"
echo -e "${GREEN}✓ Redis password configured${NC}"
echo ""

# Step 3: RBAC
echo -e "${BLUE}Step 3: Configuring RBAC...${NC}"
kubectl apply -f "$SCRIPT_DIR/03-rbac.yaml"
echo ""

# Step 4: TLS Certificates
echo -e "${BLUE}Step 4: Creating TLS certificates...${NC}"
kubectl apply -f "$SCRIPT_DIR/02-tls-certificates-k3s.yaml"

echo "Waiting for certificate to be ready..."
for i in {1..60}; do
    if kubectl get certificate -n $NAMESPACE redis-server-cert -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
        echo -e "${GREEN}✓ Certificate ready${NC}"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Verify secret was created
if kubectl get secret -n $NAMESPACE redis-tls-secret &>/dev/null; then
    echo -e "${GREEN}✓ TLS secret created${NC}"
else
    echo -e "${YELLOW}Warning: TLS secret not found yet. Check cert-manager logs if issues persist.${NC}"
fi
echo ""

# Step 5: ConfigMap
echo -e "${BLUE}Step 5: Creating ConfigMap...${NC}"
kubectl apply -f "$SCRIPT_DIR/10-configmap.yaml"
echo ""

# Step 6: Services
echo -e "${BLUE}Step 6: Creating services...${NC}"
kubectl apply -f "$SCRIPT_DIR/11-headless-svc.yaml"
kubectl apply -f "$SCRIPT_DIR/12-client-svc.yaml"
kubectl apply -f "$SCRIPT_DIR/13-master-svc-k3s.yaml"
echo ""

# Step 7: StatefulSets
echo -e "${BLUE}Step 7: Deploying StatefulSets...${NC}"
echo "Deploying Master..."
kubectl apply -f "$SCRIPT_DIR/21-master-statefulset-k3s.yaml"

echo "Waiting for Master to be ready..."
kubectl wait --for=condition=ready pod -l role=master -n $NAMESPACE --timeout=120s || {
    echo -e "${YELLOW}Warning: Master pod not ready after 120s${NC}"
}

echo ""
echo "Deploying Replicas..."
kubectl apply -f "$SCRIPT_DIR/22-replica-statefulset-k3s.yaml"

echo "Waiting for Replicas to be ready..."
kubectl wait --for=condition=ready pod -l role=replica -n $NAMESPACE --timeout=180s || {
    echo -e "${YELLOW}Warning: Some replica pods not ready after 180s${NC}"
}

echo ""

# Step 8: Verification
echo -e "${BLUE}Step 8: Verifying installation...${NC}"
echo ""

echo "Pods:"
kubectl get pods -n $NAMESPACE

echo ""
echo "Services:"
kubectl get svc -n $NAMESPACE

echo ""
echo "PVCs:"
kubectl get pvc -n $NAMESPACE

echo ""
echo "Certificate:"
kubectl get certificate -n $NAMESPACE

echo ""

# Get LoadBalancer IP
EXTERNAL_IP=$(kubectl get svc -n $NAMESPACE redis-master-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo -e "${GREEN}=========================================="
echo "Installation Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Redis Master-Replica cluster is deployed!"
echo ""
echo "Access Information:"
echo ""
echo "Internal (ClusterIP):"
echo "  redis-master.redis.svc.cluster.local:6379 (non-TLS)"
echo "  redis-master.redis.svc.cluster.local:6380 (TLS)"
echo ""
echo "External (LoadBalancer via ServiceLB):"
if [ "$EXTERNAL_IP" != "pending" ]; then
    echo "  ${EXTERNAL_IP}:6379 (non-TLS)"
    echo "  ${EXTERNAL_IP}:6380 (TLS)"
else
    echo "  Waiting for LoadBalancer IP..."
    echo "  Run: kubectl get svc -n redis redis-master-lb"
fi
echo ""
echo "External (NodePort - fallback):"
echo "  <NODE_IP>:30379 (non-TLS)"
echo "  <NODE_IP>:30380 (TLS)"
echo ""
echo "Credentials:"
echo "  Password: Admin@123"
echo "  (stored in redis/01-secret.yaml)"
echo ""
echo "Test connection:"
echo "  # Internal (from within cluster)"
echo "  kubectl run -it redis-cli --image=redis:7-alpine --rm -- redis-cli -h redis-master.redis.svc.cluster.local -p 6379 -a Admin@123 ping"
echo ""
echo "  # External (LoadBalancer)"
if [ "$EXTERNAL_IP" != "pending" ]; then
    echo "  redis-cli -h $EXTERNAL_IP -p 6379 -a Admin@123 ping"
else
    echo "  redis-cli -h <EXTERNAL_IP> -p 6379 -a Admin@123 ping"
fi
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n redis -o wide"
echo "  kubectl logs -n redis redis-master-0"
echo "  kubectl exec -it -n redis redis-master-0 -- redis-cli -a Admin@123 info replication"
echo ""
echo "Documentation:"
echo "  README-K3S.md - Complete guide for K3s"
echo "  README.md - Original documentation"
echo ""
