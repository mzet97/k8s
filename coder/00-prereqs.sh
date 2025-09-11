#!/usr/bin/env bash
set -euo pipefail
microk8s status --wait-ready
microk8s enable dns ingress cert-manager
kubectl apply -f namespace.yaml
kubectl apply -f secrets/coder-db-url.secret.yaml
kubectl apply -f cert-manager/clusterissuer-letsencrypt-staging.yaml
kubectl apply -f cert-manager/clusterissuer-letsencrypt-prod.yaml
