#!/usr/bin/env bash
set -euo pipefail
helm upgrade coder coder-v2/coder -n coder -f values/coder-values.yaml
kubectl -n coder rollout status deploy/coder
