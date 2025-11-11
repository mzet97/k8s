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

# Check cluster status
check_cluster_status() {
    log_info "Checking RabbitMQ cluster status..."
    
    local mgmt_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$mgmt_pod" ]; then
        log_error "No RabbitMQ pod found"
        return 1
    fi
    
    echo -e "\n${BLUE}Cluster Status:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqctl cluster_status || log_error "Failed to get cluster status"
    
    echo -e "\n${BLUE}Node Status:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqctl status || log_error "Failed to get node status"
    
    echo -e "\n${BLUE}List Nodes:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqctl list_nodes || log_error "Failed to list nodes"
}

# Check pod logs
check_pod_logs() {
    log_info "Checking RabbitMQ pod logs..."
    
    local pods=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pods" ]; then
        log_error "No RabbitMQ pods found"
        return 1
    fi
    
    for pod in $pods; do
        echo -e "\n${BLUE}Logs for pod: $pod${NC}"
        echo "================================"
        
        # Check if pod is running
        local phase=$($KUBECTL_CMD get pod -n $NAMESPACE $pod -o jsonpath='{.status.phase}')
        if [ "$phase" != "Running" ]; then
            log_error "Pod $pod is not running (phase: $phase)"
            continue
        fi
        
        # Get recent logs
        $KUBECTL_CMD logs -n $NAMESPACE $pod --tail=50 || log_error "Failed to get logs for pod $pod"
        
        # Check for common errors
        echo -e "\n${BLUE}Checking for common errors in $pod...${NC}"
        local error_patterns=("ERROR" "FATAL" "CRASH" "connection refused" "permission denied" "disk full" "memory")
        
        for pattern in "${error_patterns[@]}"; do
            if $KUBECTL_CMD logs -n $NAMESPACE $pod --tail=100 | grep -i "$pattern" > /dev/null 2>&1; then
                log_warning "Found '$pattern' in logs for pod $pod"
                $KUBECTL_CMD logs -n $NAMESPACE $pod --tail=100 | grep -i "$pattern" | head -5
            fi
        done
    done
}

# Check resource usage
check_resource_usage() {
    log_info "Checking resource usage..."
    
    local pods=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pods" ]; then
        log_error "No RabbitMQ pods found"
        return 1
    fi
    
    echo -e "\n${BLUE}Pod Resource Usage:${NC}"
    $KUBECTL_CMD top pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq || log_warning "Metrics server not available"
    
    for pod in $pods; do
        echo -e "\n${BLUE}Resource limits for pod: $pod${NC}"
        $KUBECTL_CMD describe pod -n $NAMESPACE $pod | grep -A 5 "Limits:" || log_warning "No resource limits found"
        
        # Check if pod is using too much memory
        local memory_usage=$($KUBECTL_CMD top pod -n $NAMESPACE $pod --no-headers 2>/dev/null | awk '{print $2}' || echo "0")
        local memory_limit=$($KUBECTL_CMD get pod -n $NAMESPACE $pod -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "0")
        
        if [ "$memory_usage" != "0" ] && [ "$memory_limit" != "0" ]; then
            echo "Memory usage: $memory_usage / $memory_limit"
            
            # Convert memory to bytes for comparison
            local usage_bytes=$(echo "$memory_usage" | sed 's/Mi/\*1048576/g' | sed 's/Gi/\*1073741824/g' | bc 2>/dev/null || echo "0")
            local limit_bytes=$(echo "$memory_limit" | sed 's/Mi/\*1048576/g' | sed 's/Gi/\*1073741824/g' | bc 2>/dev/null || echo "0")
            
            if [ "$usage_bytes" -gt "$((limit_bytes * 90 / 100))" ]; then
                log_warning "Pod $pod is using more than 90% of memory limit"
            fi
        fi
    done
}

# Check network connectivity
check_network_connectivity() {
    log_info "Checking network connectivity..."
    
    local mgmt_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$mgmt_pod" ]; then
        log_error "No RabbitMQ pod found"
        return 1
    fi
    
    echo -e "\n${BLUE}DNS Resolution:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- nslookup rabbitmq.$NAMESPACE.svc.cluster.local || log_error "DNS resolution failed"
    
    echo -e "\n${BLUE}Service Connectivity:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- nc -zv rabbitmq.$NAMESPACE.svc.cluster.local 5672 || log_error "Cannot connect to service on port 5672"
    
    echo -e "\n${BLUE}Management Port Connectivity:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- nc -zv localhost 15672 || log_error "Cannot connect to management port"
    
    echo -e "\n${BLUE}AMQP Port Connectivity:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- nc -zv localhost 5672 || log_error "Cannot connect to AMQP port"
}

# Check storage
check_storage() {
    log_info "Checking storage..."
    
    local pods=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pods" ]; then
        log_error "No RabbitMQ pods found"
        return 1
    fi
    
    echo -e "\n${BLUE}Persistent Volume Claims:${NC}"
    $KUBECTL_CMD get pvc -n $NAMESPACE
    
    for pod in $pods; do
        echo -e "\n${BLUE}Storage for pod: $pod${NC}"
        
        # Check disk usage
        local disk_usage=$($KUBECTL_CMD exec -n $NAMESPACE $pod -- df -h /var/lib/rabbitmq 2>/dev/null || echo "Failed to get disk usage")
        echo "$disk_usage"
        
        # Check if disk is full
        if echo "$disk_usage" | grep -q "100%"; then
            log_error "Disk is full for pod $pod"
        elif echo "$disk_usage" | grep -q "9[0-9]%"; then
            log_warning "Disk is almost full for pod $pod"
        fi
        
        # Check permissions
        local permissions=$($KUBECTL_CMD exec -n $NAMESPACE $pod -- ls -la /var/lib/rabbitmq 2>/dev/null | head -5 || echo "Failed to check permissions")
        echo "Permissions:"
        echo "$permissions"
    done
}

# Check configuration
check_configuration() {
    log_info "Checking configuration..."
    
    local mgmt_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$mgmt_pod" ]; then
        log_error "No RabbitMQ pod found"
        return 1
    fi
    
    echo -e "\n${BLUE}Configuration Files:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- ls -la /etc/rabbitmq/ || log_error "Failed to list configuration files"
    
    echo -e "\n${BLUE}Main Configuration:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- cat /etc/rabbitmq/rabbitmq.conf 2>/dev/null | head -20 || log_error "Failed to read main configuration"
    
    echo -e "\n${BLUE}Enabled Plugins:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmq-plugins list --enabled || log_error "Failed to list enabled plugins"
    
    echo -e "\n${BLUE}Environment Variables:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- env | grep RABBITMQ || log_error "Failed to get environment variables"
}

# Check cluster health
check_cluster_health() {
    log_info "Checking cluster health..."
    
    local mgmt_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$mgmt_pod" ]; then
        log_error "No RabbitMQ pod found"
        return 1
    fi
    
    echo -e "\n${BLUE}Node Health Check:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqctl node_health_check || log_error "Node health check failed"
    
    echo -e "\n${BLUE}Memory Usage:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqctl status | grep -A 5 "Memory" || log_error "Failed to get memory usage"
    
    echo -e "\n${BLUE}Disk Usage:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqctl status | grep -A 5 "Disk" || log_error "Failed to get disk usage"
    
    echo -e "\n${BLUE}Alarms:${NC}"
    local alarms=$($KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- rabbitmqctl list_alarms 2>/dev/null || echo "Failed to get alarms")
    if [ "$alarms" != "" ] && [ "$alarms" != "Listing alarms ..." ]; then
        log_warning "Active alarms found:"
        echo "$alarms"
    else
        log_success "No active alarms"
    fi
}

# Check services
check_services() {
    log_info "Checking services..."
    
    echo -e "\n${BLUE}Service Status:${NC}"
    $KUBECTL_CMD get svc -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq
    
    echo -e "\n${BLUE}Service Endpoints:${NC}"
    $KUBECTL_CMD get endpoints -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq
    
    echo -e "\n${BLUE}Ingress Status:${NC}"
    $KUBECTL_CMD get ingress -n $NAMESPACE 2>/dev/null || log_warning "No ingress resources found"
}

# Check for common issues
check_common_issues() {
    log_info "Checking for common issues..."
    
    local pods=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pods" ]; then
        log_error "No RabbitMQ pods found"
        return 1
    fi
    
    for pod in $pods; do
        echo -e "\n${BLUE}Checking pod: $pod${NC}"
        
        # Check pod events
        echo "Recent events:"
        $KUBECTL_CMD get events -n $NAMESPACE --field-selector involvedObject.name=$pod --sort-by='.lastTimestamp' | tail -10
        
        # Check pod conditions
        local conditions=$($KUBECTL_CMD get pod -n $NAMESPACE $pod -o jsonpath='{.status.conditions[*].type}')
        for condition in $conditions; do
            local status=$($KUBECTL_CMD get pod -n $NAMESPACE $pod -o jsonpath="{.status.conditions[?(@.type=='$condition')].status}")
            local reason=$($KUBECTL_CMD get pod -n $NAMESPACE $pod -o jsonpath="{.status.conditions[?(@.type=='$condition')].reason}")
            
            if [ "$status" != "True" ]; then
                log_warning "Pod $pod: $condition is $status (reason: $reason)"
            fi
        done
        
        # Check if pod is stuck in pending
        local phase=$($KUBECTL_CMD get pod -n $NAMESPACE $pod -o jsonpath='{.status.phase}')
        if [ "$phase" == "Pending" ]; then
            log_warning "Pod $pod is stuck in Pending state"
            
            # Check for common pending reasons
            local pending_reason=$($KUBECTL_CMD get pod -n $NAMESPACE $pod -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].reason}')
            case "$pending_reason" in
                "Unschedulable")
                    log_error "Pod $pod cannot be scheduled - check node resources and affinity rules"
                    ;;
                "NodeAffinity")
                    log_error "Pod $pod has node affinity issues"
                    ;;
                *)
                    log_warning "Pod $pod pending reason: $pending_reason"
                    ;;
            esac
        fi
        
        # Check if pod is crashlooping
        local restart_count=$($KUBECTL_CMD get pod -n $NAMESPACE $pod -o jsonpath='{.status.containerStatuses[0].restartCount}')
        if [ "$restart_count" -gt 5 ]; then
            log_error "Pod $pod has restarted $restart_count times (possible crash loop)"
        fi
    done
}

# Show usage
show_usage() {
    echo "RabbitMQ Troubleshooting Script"
    echo "Usage: $0 [check]"
    echo ""
    echo "Checks:"
    echo "  all          - Run all checks (default)"
    echo "  cluster      - Check cluster status"
    echo "  logs         - Check pod logs"
    echo "  resources    - Check resource usage"
    echo "  network      - Check network connectivity"
    echo "  storage      - Check storage"
    echo "  config       - Check configuration"
    echo "  health       - Check cluster health"
    echo "  services     - Check services"
    echo "  issues       - Check for common issues"
    echo "  help         - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 all"
    echo "  $0 cluster"
    echo "  $0 logs"
    echo "  $0 issues"
}

# Run all checks
run_all_checks() {
    log_info "Running all RabbitMQ troubleshooting checks..."
    echo "================================"
    
    check_cluster_status
    echo
    
    check_pod_logs
    echo
    
    check_resource_usage
    echo
    
    check_network_connectivity
    echo
    
    check_storage
    echo
    
    check_configuration
    echo
    
    check_cluster_health
    echo
    
    check_services
    echo
    
    check_common_issues
    echo
    
    log_success "All troubleshooting checks completed!"
}

# Main function
main() {
    case "${1:-all}" in
        all)
            run_all_checks
            ;;
        cluster)
            check_cluster_status
            ;;
        logs)
            check_pod_logs
            ;;
        resources)
            check_resource_usage
            ;;
        network)
            check_network_connectivity
            ;;
        storage)
            check_storage
            ;;
        config)
            check_configuration
            ;;
        health)
            check_cluster_health
            ;;
        services)
            check_services
            ;;
        issues)
            check_common_issues
            ;;
        help)
            show_usage
            ;;
        *)
            log_error "Unknown check: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"