#!/usr/bin/env bash
set -euo pipefail
helm repo add coder-v2 https://helm.coder.com/v2
helm repo update
helm upgrade --install coder coder-v2/coder -n coder -f values/coder-values.yaml
