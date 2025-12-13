#!/bin/bash

set -e

echo "Deploying MinIO with NGINX Gateway Fabric..."

# 1. Create Namespace
kubectl apply -f 00-namespace.yaml

# 2. Create Secrets
kubectl apply -f 01-secret.yaml

# 3. Create RBAC
kubectl apply -f 03-rbac.yaml

# 4. Deploy Services
kubectl apply -f 11-headless-svc.yaml
kubectl apply -f 12-client-svc.yaml

# 5. Deploy StatefulSet
kubectl apply -f 20-statefulset.yaml

# 6. Configure Gateway
kubectl apply -f 30-gateway-class.yaml
kubectl apply -f 31-gateway.yaml
kubectl apply -f 32-http-routes.yaml

echo "Waiting for MinIO pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=minio -n minio --timeout=300s

echo "MinIO deployed successfully!"
echo "API URL: http://minio.home.arpa"
echo "Console URL: http://console.minio.home.arpa"
