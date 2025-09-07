#!/bin/bash

# Redis Connection Fix Script
# This script attempts to fix common Redis connection issues

set -e

echo "=== Redis Connection Fix Script ==="
echo "This script will attempt to fix Redis connection issues"
echo

# Function to check if a resource exists
check_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    
    if microk8s kubectl get $resource_type $resource_name -n $namespace >/dev/null 2>&1; then
        echo "✓ $resource_type/$resource_name exists"
        return 0
    else
        echo "✗ $resource_type/$resource_name NOT FOUND"
        return 1
    fi
}

# Function to apply manifest if file exists
apply_if_exists() {
    local file=$1
    if [ -f "$file" ]; then
        echo "Applying $file..."
        microk8s kubectl apply -f "$file"
    else
        echo "Warning: $file not found"
    fi
}

echo "1. Checking current Redis deployment status..."
echo

# Check namespace
if ! microk8s kubectl get namespace redis >/dev/null 2>&1; then
    echo "Creating redis namespace..."
    microk8s kubectl create namespace redis
fi

echo "2. Checking and applying Redis manifests..."
echo

# Apply manifests in order
MANIFESTS=(
    "00-namespace.yaml"
    "01-secret.yaml"
    "02-tls-certificates.yaml"
    "03-rbac.yaml"
    "10-configmap.yaml"
    "11-headless-svc.yaml"
    "12-client-svc.yaml"
    "13-master-svc.yaml"
    "20-statefulset.yaml"
    "21-master-statefulset.yaml"
    "22-replica-statefulset.yaml"
    "30-bootstrap-job.yaml"
    "31-replication-setup-job.yaml"
    "40-external-access.yaml"
    "42-redis-proxy-tls.yaml"
)

for manifest in "${MANIFESTS[@]}"; do
    apply_if_exists "$manifest"
done

echo
echo "3. Waiting for pods to be ready..."
echo "This may take a few minutes..."
echo

# Wait for pods to be ready
echo "Waiting for Redis master..."
microk8s kubectl wait --for=condition=ready pod -l app=redis-master -n redis --timeout=300s || echo "Warning: Redis master not ready"

echo "Waiting for Redis proxy..."
microk8s kubectl wait --for=condition=ready pod -l app=redis-proxy -n redis --timeout=300s || echo "Warning: Redis proxy not ready"

echo
echo "4. Checking service status..."
echo

# Check critical services
check_resource "service" "redis-master" "redis"
check_resource "service" "redis-proxy-service" "redis"
check_resource "secret" "redis-auth" "redis"
check_resource "secret" "redis-tls" "redis"

echo
echo "5. Testing internal connectivity..."
echo

# Test internal connectivity
echo "Testing Redis master internal connectivity..."
if microk8s kubectl run redis-test-master --image=redis:7-alpine --rm -i --restart=Never -n redis -- redis-cli -h redis-master.redis.svc.cluster.local -p 6379 -a Admin@123 ping 2>/dev/null | grep -q PONG; then
    echo "✓ Redis master internal connection successful"
else
    echo "✗ Redis master internal connection failed"
fi

echo
echo "6. Getting connection information..."
echo

# Get node IP
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Node IP: $NODE_IP"

# Get NodePort services
echo "Available external ports:"
microk8s kubectl get svc -n redis --field-selector spec.type=NodePort -o custom-columns="NAME:.metadata.name,PORTS:.spec.ports[*].nodePort"

echo
echo "7. Connection test commands:"
echo
echo "Try these commands to test Redis connectivity:"
echo
echo "# Non-TLS connection via proxy:"
echo "redis-cli -h $NODE_IP -p 30379 -a Admin@123 ping"
echo
echo "# TLS connection via proxy:"
echo "redis-cli -h $NODE_IP -p 30380 --tls --insecure -a Admin@123 ping"
echo
echo "# Direct connection to Redis nodes:"
echo "redis-cli -h $NODE_IP -p 30079 -a Admin@123 ping  # Node 0"
echo "redis-cli -h $NODE_IP -p 30080 -a Admin@123 ping  # Node 1"
echo "redis-cli -h $NODE_IP -p 30081 -a Admin@123 ping  # Node 2"
echo
echo "# Port forwarding (if external access fails):"
echo "microk8s kubectl port-forward svc/redis-master 6379:6379 -n redis &"
echo "redis-cli -h localhost -p 6379 -a Admin@123 ping"
echo
echo "# Check HAProxy stats:"
echo "curl -u admin:admin123 http://$NODE_IP:30404/stats"
echo

echo "8. Troubleshooting tips:"
echo
echo "If connections still fail:"
echo "1. Check pod logs: microk8s kubectl logs -l app=redis-proxy -n redis"
echo "2. Check Redis master logs: microk8s kubectl logs -l app=redis-master -n redis"
echo "3. Verify TLS certificates: microk8s kubectl describe secret redis-tls -n redis"
echo "4. Check if firewall is blocking ports 30379, 30380"
echo "5. Verify DNS resolution: nslookup redis.home.arpa"
echo
echo "=== Fix script completed ==="