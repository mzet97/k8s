#!/bin/bash
set -e

echo "=== Verificando Resource Limits e Health Checks ==="

# Função para verificar recursos de um pod
check_pod_resources() {
    local namespace=$1
    local label=$2
    
    echo ""
    echo "Verificando pods com label $label no namespace $namespace:"
    
    kubectl get pods -n "$namespace" -l "$label" -o custom-columns=\
NAME:.metadata.name,\
CPU_REQUEST:.spec.containers[0].resources.requests.cpu,\
CPU_LIMIT:.spec.containers[0].resources.limits.cpu,\
MEMORY_REQUEST:.spec.containers[0].resources.requests.memory,\
MEMORY_LIMIT:.spec.containers[0].resources.limits.memory,\
READY:.status.containerStatuses[0].ready
}

# Função para verificar health checks
check_health_checks() {
    local namespace=$1
    local deployment=$2
    
    echo ""
    echo "Verificando health checks do deployment $deployment no namespace $namespace:"
    
    kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{
        "Liveness Probe: {.spec.template.spec.containers[0].livenessProbe.httpGet.path} (port: {.spec.template.spec.containers[0].livenessProbe.httpGet.port})\n"
        "Readiness Probe: {.spec.template.spec.containers[0].readinessProbe.httpGet.path} (port: {.spec.template.spec.containers[0].readinessProbe.httpGet.port})\n"
        "Startup Probe: {.spec.template.spec.containers[0].startupProbe.httpGet.path} (port: {.spec.template.spec.containers[0].startupProbe.httpGet.port})\n"
    }'
}

# Função para verificar limit ranges e resource quotas
check_resource_policies() {
    local namespace=$1
    
    echo ""
    echo "Verificando LimitRanges e ResourceQuotas no namespace $namespace:"
    
    echo "LimitRanges:"
    kubectl get limitranges -n "$namespace" -o wide || echo "Nenhum LimitRange encontrado"
    
    echo "ResourceQuotas:"
    kubectl get resourcequotas -n "$namespace" -o wide || echo "Nenhum ResourceQuota encontrado"
}

# Verificar namespaces
echo "Namespaces disponíveis:"
kubectl get namespaces

# Verificar resource limits nos principais namespaces
for ns in default monitoring production development; do
    if kubectl get namespace "$ns" &> /dev/null; then
        echo ""
        echo "=== Namespace: $ns ==="
        check_resource_policies "$ns"
        
        # Verificar pods comuns
        check_pod_resources "$ns" "app=prometheus"
        check_pod_resources "$ns" "app=grafana"
        check_pod_resources "$ns" "app=example-app"
    fi
done

# Verificar health checks específicos
echo ""
echo "=== Verificando Health Checks Específicos ==="

if kubectl get deployment prometheus-with-resources -n monitoring &> /dev/null; then
    check_health_checks "monitoring" "prometheus-with-resources"
fi

if kubectl get deployment grafana-with-resources -n monitoring &> /dev/null; then
    check_health_checks "monitoring" "grafana-with-resources"
fi

if kubectl get deployment app-with-resources -n default &> /dev/null; then
    check_health_checks "default" "app-with-resources"
fi

echo ""
echo "=== Testando Health Checks ==="

# Testar endpoints de health
if kubectl get service prometheus-service -n monitoring &> /dev/null; then
    echo "Testando Prometheus health endpoint..."
    kubectl run health-test --image=curlimages/curl:latest --rm -i --restart=Never -- \
        curl -s -o /dev/null -w "%{http_code}" http://prometheus-service.monitoring.svc.cluster.local:9090/-/healthy || echo "Falha ao testar Prometheus"
fi

if kubectl get service grafana-service -n monitoring &> /dev/null; then
    echo "Testando Grafana health endpoint..."
    kubectl run grafana-health-test --image=curlimages/curl:latest --rm -i --restart=Never -- \
        curl -s -o /dev/null -w "%{http_code}" http://grafana-service.monitoring.svc.cluster.local:3000/api/health || echo "Falha ao testar Grafana"
fi

echo ""
echo "=== Verificando Uso de Recursos ==="

# Verificar uso de recursos do cluster
echo "Uso de recursos por namespace:"
kubectl top nodes || echo "Metrics não disponíveis - certifique-se de que o metrics-server está instalado"

echo ""
echo "Uso de recursos por pod:"
kubectl top pods -A || echo "Metrics não disponíveis"

echo ""
echo "=== Verificando Eventos de Recursos ==="

# Verificar eventos relacionados a recursos
echo "Eventos de OOMKilled (Out of Memory):"
kubectl get events -A --field-selector reason=OOMKilled --sort-by='.lastTimestamp' || echo "Nenhum evento OOMKilled encontrado"

echo ""
echo "Eventos de FailedScheduling (recursos insuficientes):"
kubectl get events -A --field-selector reason=FailedScheduling --sort-by='.lastTimestamp' || echo "Nenhum evento FailedScheduling encontrado"

echo ""
echo "=== Diagnóstico Completo ==="
echo "Use este script para verificar a saúde dos recursos e health checks do cluster."
echo "Para aplicar as configurações de exemplo:"
echo "kubectl apply -f applications/resource-limits/"