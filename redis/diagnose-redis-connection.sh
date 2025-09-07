#!/bin/bash

# Redis Connection Diagnostic Script
# This script helps diagnose Redis connection issues

echo "=== Redis Connection Diagnostic ==="
echo "Date: $(date)"
echo

# Check if we're in the right namespace
echo "1. Checking Redis namespace and resources..."
echo "Pods in redis namespace:"
microk8s kubectl get pods -n redis -o wide
echo
echo "Services in redis namespace:"
microk8s kubectl get svc -n redis
echo
echo "Secrets in redis namespace:"
microk8s kubectl get secrets -n redis
echo

# Check specific services that should exist
echo "2. Checking specific Redis services..."
echo "Checking redis-master service:"
microk8s kubectl get svc redis-master -n redis 2>/dev/null || echo "redis-master service NOT FOUND"
echo "Checking redis-proxy-service:"
microk8s kubectl get svc redis-proxy-service -n redis 2>/dev/null || echo "redis-proxy-service NOT FOUND"
echo "Checking redis-cluster service:"
microk8s kubectl get svc redis-cluster -n redis 2>/dev/null || echo "redis-cluster service NOT FOUND"
echo

# Check pod status and logs
echo "3. Checking pod status and recent logs..."
for pod in $(microk8s kubectl get pods -n redis --no-headers -o custom-columns=":metadata.name"); do
    echo "Pod: $pod"
    echo "Status: $(microk8s kubectl get pod $pod -n redis --no-headers -o custom-columns=":status.phase")"
    echo "Recent logs (last 10 lines):"
    microk8s kubectl logs $pod -n redis --tail=10 2>/dev/null || echo "No logs available"
    echo "---"
done
echo

# Check node IP and external access
echo "4. Checking external access configuration..."
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Node IP: $NODE_IP"
echo
echo "NodePort services:"
microk8s kubectl get svc -n redis --field-selector spec.type=NodePort
echo

# Test internal connectivity
echo "5. Testing internal connectivity..."
echo "Testing if redis-master is reachable internally:"
microk8s kubectl run redis-test --image=redis:7-alpine --rm -it --restart=Never -n redis -- redis-cli -h redis-master.redis.svc.cluster.local -p 6380 --tls --insecure -a Admin@123 ping 2>/dev/null || echo "Internal connection to redis-master failed"
echo
echo "Testing if redis-proxy-service is reachable internally:"
microk8s kubectl run redis-test --image=redis:7-alpine --rm -it --restart=Never -n redis -- redis-cli -h redis-proxy-service.redis.svc.cluster.local -p 6379 -a Admin@123 ping 2>/dev/null || echo "Internal connection to redis-proxy-service failed"
echo

# Check TLS certificates
echo "6. Checking TLS certificates..."
echo "TLS secrets:"
microk8s kubectl get secrets -n redis | grep tls
echo
echo "Redis TLS secret details:"
microk8s kubectl describe secret redis-tls-secret -n redis 2>/dev/null || echo "redis-tls-secret secret NOT FOUND"
echo
echo "Redis proxy TLS secret details:"
microk8s kubectl describe secret redis-proxy-tls -n redis 2>/dev/null || echo "redis-proxy-tls secret NOT FOUND"
echo

# Check configurations
echo "7. Checking configurations..."
echo "Redis auth secret:"
microk8s kubectl get secret redis-auth -n redis -o jsonpath='{.data.REDIS_PASSWORD}' 2>/dev/null | base64 -d && echo || echo "redis-auth secret NOT FOUND"
echo
echo "Redis proxy config:"
microk8s kubectl get configmap redis-proxy-config -n redis -o yaml 2>/dev/null || echo "redis-proxy-config NOT FOUND"
echo

# Provide connection recommendations
echo "8. Connection Recommendations:"
echo
echo "Based on the configuration, try these connection methods:"
echo
echo "A) If redis-master service exists:"
echo "   redis-cli -h $NODE_IP -p 30379 -a Admin@123 ping"
echo "   redis-cli -h $NODE_IP -p 30380 --tls --insecure -a Admin@123 ping"
echo
echo "B) If redis-cluster is running:"
echo "   redis-cli -h $NODE_IP -p 30079 -a Admin@123 ping  # Node 0"
echo "   redis-cli -h $NODE_IP -p 30080 -a Admin@123 ping  # Node 1"
echo "   redis-cli -h $NODE_IP -p 30081 -a Admin@123 ping  # Node 2"
echo
echo "C) Port forwarding (if external access fails):"
echo "   microk8s kubectl port-forward svc/redis-master 6380:6380 -n redis &"
echo "   redis-cli -h localhost -p 6380 --tls --insecure -a Admin@123 ping"
echo
echo "D) Check if services are properly deployed:"
echo "   microk8s kubectl apply -f /path/to/redis/manifests/"
echo
echo "=== End of Diagnostic ==="