#!/bin/bash

# Log file for uninstallation
LOG_FILE="/var/log/k3s-uninstall.log"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Confirmation prompt
echo "=========================================="
echo "K3s Uninstallation"
echo "=========================================="
echo ""
echo "WARNING: This will completely remove K3s from your system."
echo "All running workloads will be stopped and removed."
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Log the start of the uninstallation
log "Starting K3s uninstallation."

# Check if the uninstall script exists
if [ -f "/usr/local/bin/k3s-uninstall.sh" ]; then
    echo "Found K3s uninstall script. Proceeding with uninstallation."
    log "Executing /usr/local/bin/k3s-uninstall.sh"
    /usr/local/bin/k3s-uninstall.sh 2>&1 | tee -a "$LOG_FILE"

    if [ "${PIPESTATUS[0]}" -eq 0 ]; then
        log "K3s uninstalled successfully."
        echo ""
        echo "K3s has been uninstalled successfully."
    else
        log "K3s uninstallation failed. Check $LOG_FILE for details."
        echo ""
        echo "K3s uninstallation encountered errors. Check the log at $LOG_FILE for more details."
        echo "Attempting to clean up residual files..."
    fi
else
    log "K3s uninstall script not found. It seems K3s is not installed or was installed in a non-standard way."
    echo "K3s uninstall script not found at /usr/local/bin/k3s-uninstall.sh"
    echo ""
    echo "Attempting manual cleanup..."
fi

# Additional cleanup of residual files and directories
log "Performing additional cleanup..."
echo ""
echo "Cleaning up residual files and directories..."

# Stop K3s service if still running
if systemctl is-active --quiet k3s 2>/dev/null; then
    log "Stopping K3s service..."
    systemctl stop k3s 2>&1 | tee -a "$LOG_FILE"
fi

# Remove common K3s directories
CLEANUP_DIRS=(
    "/etc/rancher"
    "/var/lib/rancher/k3s"
    "/var/lib/kubelet"
    "/var/lib/cni"
    "/etc/cni"
    "/opt/cni"
)

for dir in "${CLEANUP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log "Removing directory: $dir"
        rm -rf "$dir" 2>&1 | tee -a "$LOG_FILE"
    fi
done

# Remove K3s binaries
if [ -f "/usr/local/bin/k3s" ]; then
    log "Removing K3s binary..."
    rm -f /usr/local/bin/k3s 2>&1 | tee -a "$LOG_FILE"
fi

# Remove kubectl symlinks if they point to k3s
if [ -L "/usr/local/bin/kubectl" ]; then
    log "Removing kubectl symlink..."
    rm -f /usr/local/bin/kubectl 2>&1 | tee -a "$LOG_FILE"
fi

log "K3s uninstallation and cleanup completed."
echo ""
echo "=========================================="
echo "Uninstallation Complete"
echo "=========================================="
echo ""
echo "K3s and related files have been removed from your system."
echo "Log file: $LOG_FILE"
echo ""
echo "Note: User kubeconfig files in ~/.kube/ were not removed."
echo "You may want to clean them manually if needed."
echo ""
