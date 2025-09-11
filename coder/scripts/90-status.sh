#!/usr/bin/env bash
set -euo pipefail
kubectl -n coder get pods,svc,ingress
kubectl -n coder describe certificate coder-tls || true
kubectl -n coder logs deploy/coder --tail=100 | tail -n +1
