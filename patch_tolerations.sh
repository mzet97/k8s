#!/bin/bash

# Patch all deployments and statefulsets to tolerate disk pressure
# This is an emergency measure to get services back up while disk is high

namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')

for ns in $namespaces; do
    echo "Processing namespace: $ns"
    
    # Patch deployments
    deployments=$(kubectl get deployments -n $ns -o jsonpath='{.items[*].metadata.name}')
    for dep in $deployments; do
        echo "  Patching deployment: $dep"
        kubectl patch deployment $dep -n $ns --type='json' -p='[{"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {"key": "node.kubernetes.io/disk-pressure", "operator": "Exists", "effect": "NoSchedule"}}]' 2>/dev/null || \
        kubectl patch deployment $dep -n $ns --type='json' -p='[{"op": "add", "path": "/spec/template/spec/tolerations", "value": [{"key": "node.kubernetes.io/disk-pressure", "operator": "Exists", "effect": "NoSchedule"}]}]'
    done

    # Patch statefulsets
    statefulsets=$(kubectl get statefulsets -n $ns -o jsonpath='{.items[*].metadata.name}')
    for sts in $statefulsets; do
        echo "  Patching statefulset: $sts"
        kubectl patch statefulset $sts -n $ns --type='json' -p='[{"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {"key": "node.kubernetes.io/disk-pressure", "operator": "Exists", "effect": "NoSchedule"}}]' 2>/dev/null || \
        kubectl patch statefulset $sts -n $ns --type='json' -p='[{"op": "add", "path": "/spec/template/spec/tolerations", "value": [{"key": "node.kubernetes.io/disk-pressure", "operator": "Exists", "effect": "NoSchedule"}]}]'
    done
done
