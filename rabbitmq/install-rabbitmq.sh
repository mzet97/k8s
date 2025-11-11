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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! $KUBECTL_CMD cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check namespace
    if ! $KUBECTL_CMD get namespace $NAMESPACE &> /dev/null; then
        log_info "Creating namespace $NAMESPACE..."
        $KUBECTL_CMD apply -f $SCRIPT_DIR/00-namespace.yaml
    fi
    
    # Check cert-manager
    if ! $KUBECTL_CMD get crd certificates.cert-manager.io &> /dev/null; then
        log_warning "cert-manager not found. TLS certificates will not be available."
        return 1
    fi
    
    # Check storage class
    if ! $KUBECTL_CMD get storageclass local-path &> /dev/null; then
        log_warning "Storage class 'local-path' not found. Using default storage class."
    fi
    
    # Check ingress controller
    if ! $KUBECTL_CMD get pods -n ingress-nginx &> /dev/null; then
        log_warning "Ingress controller not found. External access will be limited."
    fi
    
    # Check prometheus operator
    if ! $KUBECTL_CMD get crd servicemonitors.monitoring.coreos.com &> /dev/null; then
        log_warning "Prometheus Operator not found. Monitoring will be limited."
    fi
    
    log_success "Prerequisites check completed"
}

# Install RabbitMQ
install_rabbitmq() {
    log_info "Installing RabbitMQ..."
    
    # Apply secrets
    log_info "Creating secrets..."
    $KUBECTL_CMD apply -f $SCRIPT_DIR/01-secret.yaml
    
    # Apply TLS certificates
    log_info "Creating TLS certificates..."
    $KUBECTL_CMD apply -f $SCRIPT_DIR/02-tls-certificates.yaml || log_warning "TLS certificates creation failed"
    
    # Apply RBAC
    log_info "Creating RBAC..."
    $KUBECTL_CMD apply -f $SCRIPT_DIR/03-rbac.yaml
    
    # Apply configmap
    log_info "Creating configuration..."
    $KUBECTL_CMD apply -f $SCRIPT_DIR/10-configmap.yaml
    
    # Apply services
    log_info "Creating services..."
    $KUBECTL_CMD apply -f $SCRIPT_DIR/11-headless-svc.yaml
    $KUBECTL_CMD apply -f $SCRIPT_DIR/12-client-svc.yaml
    $KUBECTL_CMD apply -f $SCRIPT_DIR/13-management-svc.yaml
    $KUBECTL_CMD apply -f $SCRIPT_DIR/14-nodeport-svc.yaml
    
    # Apply basic auth secret
    log_info "Creating basic auth..."
    $KUBECTL_CMD apply -f $SCRIPT_DIR/32-basic-auth-secret.yaml
    
    # Apply TCP services configmap
    log_info "Creating TCP services configmap..."
    $KUBECTL_CMD apply -f $SCRIPT_DIR/33-tcp-services-configmap.yaml
    
    # Apply statefulset
    log_info "Creating RabbitMQ cluster..."
    $KUBECTL_CMD apply -f $SCRIPT_DIR/20-statefulset.yaml
    
    # Apply monitoring
    log_info "Creating monitoring..."
    if $KUBECTL_CMD get crd servicemonitors.monitoring.coreos.com &> /dev/null; then
        $KUBECTL_CMD apply -f $SCRIPT_DIR/60-monitoring.yaml || log_warning "Monitoring setup failed"
    else
        log_warning "ServiceMonitor CRD not found. Skipping monitoring setup."
    fi
    if $KUBECTL_CMD get crd prometheusrules.monitoring.coreos.com &> /dev/null; then
        $KUBECTL_CMD apply -f $SCRIPT_DIR/61-prometheus-rules.yaml || log_warning "Prometheus rules setup failed"
    else
        log_warning "PrometheusRule CRD not found. Skipping Prometheus rules setup."
    fi
    
    # Apply ingress
    log_info "Creating ingress..."
    $KUBECTL_CMD apply -f $SCRIPT_DIR/30-management-ingress.yaml || log_warning "Management ingress creation failed"
    $KUBECTL_CMD apply -f $SCRIPT_DIR/31-amqp-ingress.yaml || log_warning "AMQP ingress creation failed"
    
    log_success "RabbitMQ installation completed"
}

# Wait for RabbitMQ to be ready
wait_for_rabbitmq() {
    log_info "Waiting for RabbitMQ to be ready..."
    
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if $KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq --field-selector=status.phase=Running | grep -q "Running"; then
            log_success "RabbitMQ pods are running"
            break
        fi
        
        log_info "Waiting for RabbitMQ pods... (attempt $attempt/$max_attempts)"
        sleep 30
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "RabbitMQ pods failed to start within the expected time"
        return 1
    fi
    
    # Wait for cluster to be ready
    log_info "Waiting for RabbitMQ cluster to be ready..."
    sleep 60
    
    # Check cluster status
    local cluster_ready=false
    for i in {1..10}; do
        if $KUBECTL_CMD exec -n $NAMESPACE rabbitmq-0 -- rabbitmqctl cluster_status | grep -q "running_nodes"; then
            cluster_ready=true
            break
        fi
        log_info "Waiting for cluster formation... (attempt $i/10)"
        sleep 30
    done
    
    if [ "$cluster_ready" = true ]; then
        log_success "RabbitMQ cluster is ready"
    else
        log_warning "RabbitMQ cluster may not be fully ready"
    fi
}

# Test RabbitMQ
test_rabbitmq() {
    log_info "Testing RabbitMQ..."
    
    # Test pod status
    log_info "Checking pod status..."
    $KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq
    
    # Test service endpoints
    log_info "Checking services..."
    $KUBECTL_CMD get svc -n $NAMESPACE
    
    # Test cluster status
    log_info "Checking cluster status..."
    $KUBECTL_CMD exec -n $NAMESPACE rabbitmq-0 -- rabbitmqctl cluster_status || log_warning "Cluster status check failed"
    
    # Test management UI
    log_info "Testing management UI..."
    if $KUBECTL_CMD get ingress -n $NAMESPACE | grep -q rabbitmq; then
        local ingress_host=$($KUBECTL_CMD get ingress rabbitmq-management -n $NAMESPACE -o jsonpath='{.spec.rules[0].host}')
        log_info "Management UI available at: https://$ingress_host (user: admin, pass: rabbitmq-admin-2024!)"
    fi
    
    # Test NodePort access
    local node_port=$($KUBECTL_CMD get svc rabbitmq-nodeport -n $NAMESPACE -o jsonpath='{.spec.ports[?(@.name=="management")].nodePort}')
    log_info "NodePort access available at: http://localhost:$node_port (user: admin, pass: rabbitmq-admin-2024!)"
    
    # Test metrics endpoint
    log_info "Testing metrics endpoint..."
    $KUBECTL_CMD exec -n $NAMESPACE rabbitmq-0 -- wget -q -O- http://localhost:15692/metrics | head -20 || log_warning "Metrics endpoint test failed"
    
    log_success "RabbitMQ tests completed"
}

# Show status
show_status() {
    log_info "RabbitMQ Status:"
    echo "===================="
    
    echo -e "\n${BLUE}Pods:${NC}"
    $KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq
    
    echo -e "\n${BLUE}Services:${NC}"
    $KUBECTL_CMD get svc -n $NAMESPACE
    
    echo -e "\n${BLUE}Ingress:${NC}"
    $KUBECTL_CMD get ingress -n $NAMESPACE
    
    echo -e "\n${BLUE}Persistent Volumes:${NC}"
    $KUBECTL_CMD get pvc -n $NAMESPACE
    
    echo -e "\n${BLUE}Cluster Status:${NC}"
    $KUBECTL_CMD exec -n $NAMESPACE rabbitmq-0 -- rabbitmqctl cluster_status 2>/dev/null || echo "Cluster status unavailable"
    
    echo -e "\n${BLUE}Access Information:${NC}"
    echo "Management UI:"
    if $KUBECTL_CMD get ingress rabbitmq-management -n $NAMESPACE &>/dev/null; then
        local ingress_host=$($KUBECTL_CMD get ingress rabbitmq-management -n $NAMESPACE -o jsonpath='{.spec.rules[0].host}')
        echo "  - HTTPS: https://$ingress_host (admin/rabbitmq-admin-2024!)"
    fi
    local node_port=$($KUBECTL_CMD get svc rabbitmq-nodeport -n $NAMESPACE -o jsonpath='{.spec.ports[?(@.name=="management")].nodePort}')
    echo "  - NodePort: http://localhost:$node_port (admin/rabbitmq-admin-2024!)"
    
    echo -e "\nAMQP Connection:"
    local amqp_node_port=$($KUBECTL_CMD get svc rabbitmq-nodeport -n $NAMESPACE -o jsonpath='{.spec.ports[?(@.name=="amqp")].nodePort}')
    echo "  - NodePort: localhost:$amqp_node_port"
    echo "  - Default vhost: /"
    echo "  - Default user: appuser"
    echo "  - Default pass: rabbitmq-app-secure-2024!"
}

# Port forward for local access
port_forward() {
    log_info "Setting up port forwarding..."
    
    log_info "Management UI: http://localhost:15672 (admin/rabbitmq-admin-2024!)"
    $KUBECTL_CMD port-forward -n $NAMESPACE svc/rabbitmq-management 15672:15672 &
    
    log_info "AMQP: localhost:5672"
    $KUBECTL_CMD port-forward -n $NAMESPACE svc/rabbitmq 5672:5672 &
    
    log_info "Metrics: http://localhost:15692/metrics"
    $KUBECTL_CMD port-forward -n $NAMESPACE svc/rabbitmq-prometheus 15692:15692 &
    
    log_info "Port forwarding started. Press Ctrl+C to stop."
    wait
}

# Cleanup
remove_rabbitmq() {
    log_info "Removing RabbitMQ..."
    
    # Delete all resources
    $KUBECTL_CMD delete -f $SCRIPT_DIR/30-management-ingress.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/31-amqp-ingress.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/61-prometheus-rules.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/60-monitoring.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/20-statefulset.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/33-tcp-services-configmap.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/32-basic-auth-secret.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/14-nodeport-svc.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/13-management-svc.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/12-client-svc.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/11-headless-svc.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/10-configmap.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/03-rbac.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/02-tls-certificates.yaml --ignore-not-found=true
    $KUBECTL_CMD delete -f $SCRIPT_DIR/01-secret.yaml --ignore-not-found=true
    
    # Delete persistent volumes
    log_info "Deleting persistent volumes..."
    $KUBECTL_CMD delete pvc -n $NAMESPACE --all --ignore-not-found=true
    
    # Delete namespace
    read -p "Delete namespace $NAMESPACE? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        $KUBECTL_CMD delete namespace $NAMESPACE --ignore-not-found=true
        log_success "Namespace $NAMESPACE deleted"
    fi
    
    log_success "RabbitMQ removal completed"
}

# Show usage
show_usage() {
    echo "RabbitMQ Installation Script"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install      - Install RabbitMQ cluster"
    echo "  status       - Show RabbitMQ status"
    echo "  test         - Test RabbitMQ installation"
    echo "  port-forward - Setup port forwarding for local access"
    echo "  remove       - Remove RabbitMQ cluster"
    echo "  help         - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 status"
    echo "  $0 test"
    echo "  $0 port-forward"
    echo "  $0 remove"
}

# Main function
main() {
    case "${1:-install}" in
        install)
            check_prerequisites
            install_rabbitmq
            wait_for_rabbitmq
            test_rabbitmq
            show_status
            ;;
        status)
            show_status
            ;;
        test)
            test_rabbitmq
            ;;
        port-forward)
            port_forward
            ;;
        remove)
            remove_rabbitmq
            ;;
        help)
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"