#!/bin/bash

# Redis Connection Test Script
# Tests various Redis connection methods to identify working connections

echo "=== Redis Connection Test ==="
echo "Testing different Redis connection methods..."
echo

# Get node IP
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
if [ -z "$NODE_IP" ]; then
    echo "Error: Could not get node IP. Is microk8s running?"
    exit 1
fi

echo "Node IP: $NODE_IP"
echo "Redis password: Admin@123"
echo

# Function to test connection
test_connection() {
    local description="$1"
    local host="$2"
    local port="$3"
    local tls_flag="$4"
    local password="Admin@123"
    
    echo -n "Testing $description ($host:$port)... "
    
    if [ "$tls_flag" = "--tls" ]; then
        result=$(timeout 5 redis-cli -h "$host" -p "$port" --tls --insecure -a "$password" ping 2>/dev/null)
    else
        result=$(timeout 5 redis-cli -h "$host" -p "$port" -a "$password" ping 2>/dev/null)
    fi
    
    if [ "$result" = "PONG" ]; then
        echo "✓ SUCCESS"
        return 0
    else
        echo "✗ FAILED"
        return 1
    fi
}

# Function to test port forwarding
test_port_forward() {
    local service="$1"
    local local_port="$2"
    local remote_port="$3"
    
    echo "Testing port forward to $service..."
    
    # Start port forward in background
    microk8s kubectl port-forward "svc/$service" "$local_port:$remote_port" -n redis >/dev/null 2>&1 &
    local pf_pid=$!
    
    # Wait a moment for port forward to establish
    sleep 2
    
    # Test connection
    local result=$(timeout 3 redis-cli -h localhost -p "$local_port" -a Admin@123 ping 2>/dev/null)
    
    # Kill port forward
    kill $pf_pid 2>/dev/null
    wait $pf_pid 2>/dev/null
    
    if [ "$result" = "PONG" ]; then
        echo "✓ Port forward to $service works"
        return 0
    else
        echo "✗ Port forward to $service failed"
        return 1
    fi
}

echo "1. Testing external connections via NodePort..."
echo

# Test proxy connections (most likely to work)
test_connection "Redis Proxy (non-TLS)" "$NODE_IP" "30379" ""
test_connection "Redis Proxy (TLS)" "$NODE_IP" "30380" "--tls"

echo
echo "2. Testing direct Redis node connections..."
echo

# Test direct node connections
test_connection "Redis Node 0" "$NODE_IP" "30079" ""
test_connection "Redis Node 1" "$NODE_IP" "30080" ""
test_connection "Redis Node 2" "$NODE_IP" "30081" ""

echo
echo "3. Testing hostname-based connections..."
echo

# Test with hostnames (if configured)
test_connection "Redis via redis.home.arpa (non-TLS)" "redis.home.arpa" "30379" ""
test_connection "Redis via redis.home.arpa (TLS)" "redis.home.arpa" "30380" "--tls"
test_connection "Redis via redis-proxy.home.arpa (non-TLS)" "redis-proxy.home.arpa" "30379" ""
test_connection "Redis via redis-proxy.home.arpa (TLS)" "redis-proxy.home.arpa" "30380" "--tls"

echo
echo "4. Testing internal connections via port forwarding..."
echo

# Check what services exist
echo "Available services in redis namespace:"
microk8s kubectl get svc -n redis --no-headers -o custom-columns=":metadata.name" 2>/dev/null || echo "Could not list services"
echo

# Test port forwarding to different services
if microk8s kubectl get svc redis-master -n redis >/dev/null 2>&1; then
    test_port_forward "redis-master" "6379" "6379"
fi

if microk8s kubectl get svc redis-proxy-service -n redis >/dev/null 2>&1; then
    test_port_forward "redis-proxy-service" "6380" "6379"
fi

if microk8s kubectl get svc redis-cluster -n redis >/dev/null 2>&1; then
    test_port_forward "redis-cluster" "6381" "6379"
fi

echo
echo "5. Checking service status..."
echo

# Check pod status
echo "Redis pods status:"
microk8s kubectl get pods -n redis 2>/dev/null || echo "Could not get pods"
echo

# Check services
echo "Redis services:"
microk8s kubectl get svc -n redis 2>/dev/null || echo "Could not get services"
echo

echo "6. Recommendations:"
echo

# Provide recommendations based on what we found
echo "Based on the test results above:"
echo
echo "✓ If any external connection worked:"
echo "  Use that method for your applications"
echo
echo "✓ If port forwarding worked:"
echo "  Use: microk8s kubectl port-forward svc/[service-name] [local-port]:[remote-port] -n redis"
echo "  Then connect to: redis-cli -h localhost -p [local-port] -a Admin@123"
echo
echo "✗ If no connections worked:"
echo "  1. Check if Redis pods are running: microk8s kubectl get pods -n redis"
echo "  2. Check pod logs: microk8s kubectl logs -l app=redis-master -n redis"
echo "  3. Verify Redis is deployed: ./install-redis.sh"
echo "  4. Check firewall settings for ports 30379, 30380"
echo
echo "=== Connection test completed ==="