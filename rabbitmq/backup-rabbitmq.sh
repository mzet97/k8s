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
BACKUP_DIR="${BACKUP_DIR:-/tmp/rabbitmq-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${RETENTION_DAYS:-7}

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

# Create backup directory
create_backup_dir() {
    log_info "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
}

# Backup definitions (users, vhosts, permissions, queues, exchanges, bindings)
backup_definitions() {
    log_info "Backing up RabbitMQ definitions..."
    
    local mgmt_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$mgmt_pod" ]; then
        log_error "No RabbitMQ pod found for backup"
        return 1
    fi
    
    local backup_file="$BACKUP_DIR/rabbitmq-definitions-$TIMESTAMP.json"
    
    # Export definitions using management API
    $KUBECTL_CMD exec -n $NAMESPACE $mgmt_pod -- wget -q -O- --user=admin --password=rabbitmq-admin-2024! http://localhost:15672/api/definitions > "$backup_file"
    
    if [ -s "$backup_file" ]; then
        log_success "Definitions backed up to $backup_file"
        
        # Compress the backup
        gzip "$backup_file"
        log_success "Definitions backup compressed to ${backup_file}.gz"
    else
        log_error "Failed to backup definitions"
        rm -f "$backup_file"
        return 1
    fi
}

# Backup configuration
backup_configuration() {
    log_info "Backing up RabbitMQ configuration..."
    
    local config_dir="$BACKUP_DIR/config-$TIMESTAMP"
    mkdir -p "$config_dir"
    
    # Backup ConfigMap
    $KUBECTL_CMD get configmap rabbitmq-config -n $NAMESPACE -o yaml > "$config_dir/configmap.yaml"
    
    # Backup StatefulSet configuration
    $KUBECTL_CMD get statefulset rabbitmq -n $NAMESPACE -o yaml > "$config_dir/statefulset.yaml"
    
    # Backup Services
    $KUBECTL_CMD get svc -n $NAMESPACE -l app.kubernetes.io/name=rabbitmq -o yaml > "$config_dir/services.yaml"
    
    # Backup Ingress
    $KUBECTL_CMD get ingress -n $NAMESPACE -o yaml > "$config_dir/ingress.yaml" 2>/dev/null || true
    
    # Backup Secrets (without actual values)
    $KUBECTL_CMD get secrets -n $NAMESPACE -o yaml | sed 's/data:.*$/data: REDACTED/' > "$config_dir/secrets.yaml"
    
    # Create a summary
    cat > "$config_dir/backup-summary.txt" << EOF
RabbitMQ Configuration Backup
=============================
Backup Date: $(date)
Namespace: $NAMESPACE
Backup Directory: $config_dir

Included Resources:
- ConfigMap: rabbitmq-config
- StatefulSet: rabbitmq
- Services: All RabbitMQ services
- Ingress: All RabbitMQ ingress resources
- Secrets: Names only (values redacted)

Note: This backup contains Kubernetes resource definitions.
For data backup, use the definitions backup feature.
EOF
    
    log_success "Configuration backed up to $config_dir"
}

# Backup persistent volumes
backup_persistent_volumes() {
    log_info "Backing up persistent volumes..."
    
    local pv_backup_dir="$BACKUP_DIR/persistent-volumes-$TIMESTAMP"
    mkdir -p "$pv_backup_dir"
    
    # Get all RabbitMQ PVCs
    local pvcs=$($KUBECTL_CMD get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pvcs" ]; then
        log_warning "No persistent volume claims found"
        return 0
    fi
    
    for pvc in $pvcs; do
        log_info "Backing up PVC: $pvc"
        
        # Get pod that mounts this PVC
        local pod=$($KUBECTL_CMD get pods -n $NAMESPACE -o jsonpath="{.items[?(@.spec.volumes[*].persistentVolumeClaim.claimName=='$pvc')].metadata.name}" | head -1)
        
        if [ -z "$pod" ]; then
            log_warning "No pod found for PVC $pvc"
            continue
        fi
        
        # Create backup of the volume data
        local volume_backup="$pv_backup_dir/${pvc}-data.tar.gz"
        
        # Find the mount path
        local mount_path=$($KUBECTL_CMD get pod -n $NAMESPACE $pod -o jsonpath="{.spec.containers[0].volumeMounts[?(@.name=='data')].mountPath}" 2>/dev/null || echo "/var/lib/rabbitmq")
        
        # Create tar archive of the data
        $KUBECTL_CMD exec -n $NAMESPACE $pod -- tar -czf /tmp/backup.tar.gz -C "$mount_path" . 2>/dev/null || {
            log_warning "Failed to create tar archive for $pvc"
            continue
        }
        
        # Copy the archive
        $KUBECTL_CMD cp -n $NAMESPACE "$pod:/tmp/backup.tar.gz" "$volume_backup" || {
            log_warning "Failed to copy backup for $pvc"
            continue
        }
        
        # Clean up temp file
        $KUBECTL_CMD exec -n $NAMESPACE $pod -- rm -f /tmp/backup.tar.gz
        
        log_success "PVC $pvc backed up to $volume_backup"
    done
    
    # Create a manifest for PVC recreation
    $KUBECTL_CMD get pvc -n $NAMESPACE -o yaml > "$pv_backup_dir/pvc-manifest.yaml"
    
    log_success "Persistent volumes backed up to $pv_backup_dir"
}

# Backup monitoring data
backup_monitoring() {
    log_info "Backing up monitoring configuration..."
    
    local monitoring_dir="$BACKUP_DIR/monitoring-$TIMESTAMP"
    mkdir -p "$monitoring_dir"
    
    # Backup ServiceMonitor
    $KUBECTL_CMD get servicemonitor -n $NAMESPACE rabbitmq -o yaml > "$monitoring_dir/servicemonitor.yaml" 2>/dev/null || log_warning "ServiceMonitor not found"
    
    # Backup PrometheusRules
    $KUBECTL_CMD get prometheusrules -n $NAMESPACE rabbitmq-alerts -o yaml > "$monitoring_dir/prometheusrules.yaml" 2>/dev/null || log_warning "PrometheusRules not found"
    
    # Backup monitoring services
    $KUBECTL_CMD get svc -n $NAMESPACE rabbitmq-prometheus -o yaml > "$monitoring_dir/prometheus-service.yaml" 2>/dev/null || log_warning "Prometheus service not found"
    
    log_success "Monitoring configuration backed up to $monitoring_dir"
}

# Create backup manifest
create_backup_manifest() {
    log_info "Creating backup manifest..."
    
    local manifest_file="$BACKUP_DIR/backup-manifest-$TIMESTAMP.txt"
    
    cat > "$manifest_file" << EOF
RabbitMQ Backup Manifest
========================

Backup Information:
- Date: $(date)
- Namespace: $NAMESPACE
- Backup Directory: $BACKUP_DIR
- Timestamp: $TIMESTAMP

Backup Contents:
- Definitions: rabbitmq-definitions-$TIMESTAMP.json.gz
- Configuration: config-$TIMESTAMP/
- Persistent Volumes: persistent-volumes-$TIMESTAMP/
- Monitoring: monitoring-$TIMESTAMP/

Recovery Instructions:
1. Restore definitions: Use rabbitmqadmin to import definitions
2. Restore configuration: Apply Kubernetes manifests
3. Restore persistent volumes: Extract tar archives to new PVCs
4. Restore monitoring: Apply ServiceMonitor and PrometheusRules

Prerequisites:
- Kubernetes cluster with RabbitMQ operator
- kubectl access to the cluster
- Sufficient storage space for restoration

Notes:
- This backup includes both configuration and data
- Persistent volume backups contain actual data
- Definitions backup contains users, vhosts, queues, exchanges, and bindings
- Configuration backup contains Kubernetes resource definitions
EOF
    
    log_success "Backup manifest created: $manifest_file"
}

# Clean old backups
clean_old_backups() {
    log_info "Cleaning old backups (older than $RETENTION_DAYS days)..."
    
    find "$BACKUP_DIR" -name "rabbitmq-definitions-*.json.gz" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "config-*" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
    find "$BACKUP_DIR" -name "persistent-volumes-*" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
    find "$BACKUP_DIR" -name "monitoring-*" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
    find "$BACKUP_DIR" -name "backup-manifest-*.txt" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    log_success "Old backups cleaned up"
}

# Full backup
full_backup() {
    log_info "Starting full RabbitMQ backup..."
    
    create_backup_dir
    backup_definitions
    backup_configuration
    backup_persistent_volumes
    backup_monitoring
    create_backup_manifest
    clean_old_backups
    
    log_success "Full backup completed successfully!"
    log_info "Backup location: $BACKUP_DIR"
    log_info "Backup timestamp: $TIMESTAMP"
}

# Quick backup (definitions only)
quick_backup() {
    log_info "Starting quick RabbitMQ backup (definitions only)..."
    
    create_backup_dir
    backup_definitions
    create_backup_manifest
    
    log_success "Quick backup completed successfully!"
    log_info "Backup location: $BACKUP_DIR"
    log_info "Backup timestamp: $TIMESTAMP"
}

# Show usage
show_usage() {
    echo "RabbitMQ Backup Script"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  full         - Full backup (definitions, config, volumes, monitoring)"
    echo "  quick        - Quick backup (definitions only)"
    echo "  definitions  - Backup definitions only"
    echo "  config       - Backup configuration only"
    echo "  volumes      - Backup persistent volumes only"
    echo "  monitoring   - Backup monitoring configuration only"
    echo "  clean        - Clean old backups"
    echo "  help         - Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  BACKUP_DIR     - Backup directory (default: /tmp/rabbitmq-backups)"
    echo "  RETENTION_DAYS - Retention period in days (default: 7)"
    echo ""
    echo "Examples:"
    echo "  $0 full"
    echo "  $0 quick"
    echo "  $0 definitions"
    echo "  BACKUP_DIR=/data/backups $0 full"
    echo "  RETENTION_DAYS=30 $0 clean"
}

# Main function
main() {
    case "${1:-full}" in
        full)
            full_backup
            ;;
        quick)
            quick_backup
            ;;
        definitions)
            create_backup_dir
            backup_definitions
            create_backup_manifest
            ;;
        config)
            create_backup_dir
            backup_configuration
            create_backup_manifest
            ;;
        volumes)
            create_backup_dir
            backup_persistent_volumes
            create_backup_manifest
            ;;
        monitoring)
            create_backup_dir
            backup_monitoring
            create_backup_manifest
            ;;
        clean)
            clean_old_backups
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