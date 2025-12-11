#!/bin/bash

# Log file for installation
LOG_FILE="/var/log/k3s-install.log"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Log the start of the installation
log "Starting K3s installation."

# Install K3s with Traefik and ServiceLB enabled, making kubeconfig readable
# Traefik is the default Ingress Controller in K3s
# ServiceLB provides LoadBalancer implementation for bare-metal clusters
log "Downloading and installing K3s..."
curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    2>&1 | tee -a "$LOG_FILE"

# Check if K3s was installed successfully
if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    log "K3s installed successfully."
    echo ""
    echo "=========================================="
    echo "K3s has been installed successfully!"
    echo "=========================================="
    echo "The kubeconfig file is located at /etc/rancher/k3s/k3s.yaml"
    echo ""
    echo "Next steps:"
    echo "  1. Run: sudo ./configure-k3s.sh"
    echo "  2. Then: kubectl get nodes"
    echo ""
else
    log "K3s installation failed. Check $LOG_FILE for details."
    echo "K3s installation failed. Please check the log at $LOG_FILE for more details."
    exit 1
fi

log "K3s installation script finished."
