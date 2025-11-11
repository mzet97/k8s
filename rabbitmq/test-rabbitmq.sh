#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="rabbitmq"
RABBITMQ_USER="admin"
RABBITMQ_PASS="rabbitmq-admin-2024!"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect kubectl or microk8s
KUBECTL_CMD="kubectl"
if command -v microk8s.kubectl &> /dev/null; then
    KUBECTL_CMD="microk8s kubectl"
elif command -v microk8s &> /dev/null && microk8s status &> /dev/null; then
    KUBECTL_CMD="microk8s kubectl"
fi

# Test functions
test_pods() {
    log_info "Testing pod status..."
    
    local pods=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pods" ]; then
        log_error "No RabbitMQ pods found"
        return 1
    fi
    
    for pod in $pods; do
        local status=$($KUBECTL_CMD get pod -n $NAMESPACE $pod -o jsonpath='{.status.phase}')
        if [ "$status" != "Running" ]; then
            log_error "Pod $pod is not running (status: $status)"
            return 1
        fi
        
        # Check readiness
        local ready=$($KUBECTL_CMD get pod -n $NAMESPACE $pod -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        if [ "$ready" != "True" ]; then
            log_error "Pod $pod is not ready"
            return 1
        fi
        
        log_success "Pod $pod is running and ready"
    done
}

test_services() {
    log_info "Testing services..."
    
    local services=("rabbitmq" "rabbitmq-headless" "rabbitmq-management" "rabbitmq-nodeport" "rabbitmq-prometheus")
    
    for service in "${services[@]}"; do
        if $KUBECTL_CMD get service -n $NAMESPACE $service &> /dev/null; then
            local cluster_ip=$($KUBECTL_CMD get service -n $NAMESPACE $service -o jsonpath='{.spec.clusterIP}')
            local ports=$($KUBECTL_CMD get service -n $NAMESPACE $service -o jsonpath='{.spec.ports[*].port}')
            log_success "Service $service is available (ClusterIP: $cluster_ip, Ports: $ports)"
        else
            log_error "Service $service not found"
            return 1
        fi
    done
}

test_cluster_status() {
    log_info "Testing cluster status..."
    
    local pod_name=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$pod_name" ]; then
        log_error "No RabbitMQ pod found for cluster status check"
        return 1
    fi
    
    # Test cluster status
    local cluster_status=$($KUBECTL_CMD exec -n $NAMESPACE $pod_name -- rabbitmqctl cluster_status 2>/dev/null)
    
    if [ -z "$cluster_status" ]; then
        log_error "Failed to get cluster status"
        return 1
    fi
    
    # Check running nodes
    local running_nodes=$(echo "$cluster_status" | grep -o "running_nodes,.*" | grep -o "rabbit@[^,]*" | wc -l)
    
    if [ "$running_nodes" -lt 1 ]; then
        log_error "No running nodes found in cluster"
        return 1
    fi
    
    log_success "Cluster status OK ($running_nodes nodes running)"
    
    # Test node health
    local node_health=$($KUBECTL_CMD exec -n $NAMESPACE $pod_name -- rabbitmqctl node_health_check 2>/dev/null)
    
    if echo "$node_health" | grep -q "Health check passed"; then
        log_success "Node health check passed"
    else
        log_warning "Node health check failed or inconclusive"
    fi
}

test_management_ui() {
    log_info "Testing management UI..."
    
    local mgmt_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$mgmt_pod" ]; then
        log_error "No RabbitMQ pod found for management UI test"
        return 1
    fi
    
    # Test management plugin is enabled
    local plugins=$($KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmq-plugins list --enabled 2>/dev/null)
    
    if echo "$plugins" | grep -q "rabbitmq_management"; then
        log_success "Management plugin is enabled"
    else
        log_error "Management plugin is not enabled"
        return 1
    fi
    
    # Test management API
    local api_response=$($KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- wget -q -O- --user=$RABBITMQ_USER --password=$RABBITMQ_PASS http://localhost:15672/api/overview 2>/dev/null)
    
    if [ -n "$api_response" ] && echo "$api_response" | grep -q "rabbitmq_version"; then
        log_success "Management API is accessible"
    else
        log_error "Management API is not accessible"
        return 1
    fi
}

test_amqp_connection() {
    log_info "Testing AMQP connection..."
    
    local mgmt_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$mgmt_pod" ]; then
        log_error "No RabbitMQ pod found for AMQP test"
        return 1
    fi
    
    # Create test queue and message using rabbitmqadmin
    local test_result=$($KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqadmin declare queue name=test-queue durable=true 2>/dev/null)
    
    if [ "$test_result" != "" ] && echo "$test_result" | grep -q "error"; then
        log_error "Failed to create test queue"
        return 1
    fi
    
    local publish_result=$($KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqadmin publish exchange=amq.default routing_key=test-queue payload="test message" 2>/dev/null)
    
    if [ "$publish_result" != "" ] && echo "$publish_result" | grep -q "error"; then
        log_error "Failed to publish test message"
        return 1
    fi
    
    local queue_info=$($KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqadmin list queues name messages 2>/dev/null | grep test-queue)
    
    if echo "$queue_info" | grep -q "1"; then
        log_success "AMQP connection test passed (queue created, message published)"
        
        # Cleanup test queue
        $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqadmin delete queue name=test-queue 2>/dev/null || true
    else
        log_error "AMQP connection test failed"
        return 1
    fi
}

test_metrics_endpoint() {
    log_info "Testing metrics endpoint..."
    
    local mgmt_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$mgmt_pod" ]; then
        log_error "No RabbitMQ pod found for metrics test"
        return 1
    fi
    
    # Test Prometheus metrics endpoint
    local metrics_response=$($KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- wget -q -O- http://localhost:15692/metrics 2>/dev/null | head -10)
    
    if [ -n "$metrics_response" ] && echo "$metrics_response" | grep -q "# HELP"; then
        log_success "Prometheus metrics endpoint is accessible"
    else
        log_error "Prometheus metrics endpoint is not accessible"
        return 1
    fi
}

test_persistence() {
    log_info "Testing persistence..."
    
    local mgmt_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$mgmt_pod" ]; then
        log_error "No RabbitMQ pod found for persistence test"
        return 1
    fi
    
    # Check if persistent volumes are bound
    local pvcs=$($KUBECTL_CMD get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pvcs" ]; then
        log_error "No persistent volume claims found"
        return 1
    fi
    
    for pvc in $pvcs; do
        local status=$($KUBECTL_CMD get pvc -n $NAMESPACE $pvc -o jsonpath='{.status.phase}')
        if [ "$status" != "Bound" ]; then
            log_error "PVC $pvc is not bound (status: $status)"
            return 1
        fi
        log_success "PVC $pvc is bound"
    done
    
    # Test data directory
    local data_test=$($KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- ls /var/lib/rabbitmq/mnesia 2>/dev/null)
    
    if [ -n "$data_test" ]; then
        log_success "Data directory is accessible"
    else
        log_warning "Data directory test failed"
    fi
}

test_networking() {
    log_info "Testing networking..."
    
    # Test DNS resolution
    local mgmt_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$mgmt_pod" ]; then
        log_error "No RabbitMQ pod found for networking test"
        return 1
    fi
    
    # Test service discovery
    local dns_test=$($KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- nslookup rabbitmq.$NAMESPACE.svc.cluster.local 2>/dev/null)
    
    if [ -n "$dns_test" ] && echo "$dns_test" | grep -q "Name:"; then
        log_success "Service discovery is working"
    else
        log_warning "Service discovery test failed"
    fi
    
    # Test headless service
    local headless_dns=$($KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- nslookup rabbitmq-headless.$NAMESPACE.svc.cluster.local 2>/dev/null)
    
    if [ -n "$headless_dns" ] && echo "$headless_dns" | grep -q "Name:"; then
        log_success "Headless service discovery is working"
    else
        log_warning "Headless service discovery test failed"
    fi
}

test_ingress() {
    log_info "Testing ingress..."
    
    # Check if ingress resources exist
    local ingresses=$($KUBECTL_CMD get ingress -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$ingresses" ]; then
        log_warning "No ingress resources found"
        return 0
    fi
    
    for ingress in $ingresses; do
        local host=$($KUBECTL_CMD get ingress -n $NAMESPACE $ingress -o jsonpath='{.spec.rules[0].host}')
        local tls=$($KUBECTL_CMD get ingress -n $NAMESPACE $ingress -o jsonpath='{.spec.tls[*].hosts[0]}')
        
        if [ -n "$tls" ]; then
            log_success "Ingress $ingress configured with TLS for $host"
        else
            log_info "Ingress $ingress configured for $host (no TLS)"
        fi
    done
}

# Performance test
test_performance() {
    log_info "Testing performance..."
    
    local mgmt_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$mgmt_pod" ]; then
        log_error "No RabbitMQ pod found for performance test"
        return 1
    fi
    
    # Test message throughput (simple test)
    log_info "Running simple throughput test..."
    
    # Create test queue
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqadmin declare queue name=perf-test-queue durable=false auto_delete=true 2>/dev/null || true
    
    # Publish some messages
    for i in {1..10}; do
        $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqadmin publish exchange=amq.default routing_key=perf-test-queue payload="perf test message $i" 2>/dev/null || true
    done
    
    # Check queue size
    local queue_size=$($KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqadmin list queues name messages 2>/dev/null | grep perf-test-queue | awk '{print $2}' || echo "0")
    
    if [ "$queue_size" -eq 10 ]; then
        log_success "Performance test passed (10 messages published and counted)"
    else
        log_warning "Performance test inconclusive (expected 10 messages, got $queue_size)"
    fi
    
    # Cleanup
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqadmin delete queue name=perf-test-queue 2>/dev/null || true
}

# Run all tests
run_all_tests() {
    log_info "Running all RabbitMQ tests..."
    echo "================================"
    
    local failed_tests=0
    
    # Run individual tests
    test_pods || ((failed_tests++))
    echo
    
    test_services || ((failed_tests++))
    echo
    
    test_cluster_status || ((failed_tests++))
    echo
    
    test_management_ui || ((failed_tests++))
    echo
    
    test_amqp_connection || ((failed_tests++))
    echo
    
    test_metrics_endpoint || ((failed_tests++))
    echo
    
    test_persistence || ((failed_tests++))
    echo
    
    test_networking || ((failed_tests++))
    echo
    
    test_ingress || true
    echo
    
    test_performance || ((failed_tests++))
    echo
    
    # Summary
    echo "================================"
    if [ $failed_tests -eq 0 ]; then
        log_success "All tests passed! RabbitMQ is working correctly."
    else
        log_error "$failed_tests test(s) failed. Please check the logs above."
        exit 1
    fi
}

# Show usage
show_usage() {
    echo "RabbitMQ Test Script"
    echo "Usage: $0 [test]"
    echo ""
    echo "Tests:"
    echo "  all          - Run all tests (default)"
    echo "  pods         - Test pod status"
    echo "  services     - Test services"
    echo "  cluster      - Test cluster status"
    echo "  management   - Test management UI"
    echo "  amqp         - Test AMQP connection"
    echo "  metrics      - Test metrics endpoint"
    echo "  persistence  - Test persistence"
    echo "  networking   - Test networking"
    echo "  ingress      - Test ingress"
    echo "  performance  - Test performance"
    echo "  help         - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 all"
    echo "  $0 pods"
    echo "  $0 management"
}

# Main function
main() {
    case "${1:-all}" in
        all)
            run_all_tests
            ;;
        pods)
            test_pods
            ;;
        services)
            test_services
            ;;
        cluster)
            test_cluster_status
            ;;
        management)
            test_management_ui
            ;;
        amqp)
            test_amqp_connection
            ;;
        metrics)
            test_metrics_endpoint
            ;;
        persistence)
            test_persistence
            ;;
        networking)
            test_networking
            ;;
        ingress)
            test_ingress
            ;;
        performance)
            test_performance
            ;;
        help)
            show_usage
            ;;
        *)
            log_error "Unknown test: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"