#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Get the user who invoked sudo
if [ -n "$SUDO_USER" ]; then
    TARGET_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    USER_UID=$(id -u "$SUDO_USER")
    USER_GID=$(id -g "$SUDO_USER")
else
    echo "Error: This script must be run with sudo by a non-root user."
    echo "Usage: sudo ./configure-k3s.sh"
    exit 1
fi

K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
USER_KUBECONFIG_DIR="$USER_HOME/.kube"
USER_KUBECONFIG_PATH="$USER_KUBECONFIG_DIR/config"

echo "Configuring kubectl for user: $TARGET_USER"
echo "User home directory: $USER_HOME"

# Check if K3s kubeconfig exists
if [ ! -f "$K3S_KUBECONFIG" ]; then
    echo "Error: K3s kubeconfig file not found at $K3S_KUBECONFIG"
    echo "Please ensure K3s is installed correctly before running this script."
    exit 1
fi

# Backup existing kubeconfig if it exists
if [ -f "$USER_KUBECONFIG_PATH" ]; then
    BACKUP_PATH="$USER_KUBECONFIG_PATH.backup.$(date +%Y%m%d%H%M%S)"
    echo "Backing up existing kubeconfig to $BACKUP_PATH..."
    cp "$USER_KUBECONFIG_PATH" "$BACKUP_PATH"
    chown "$USER_UID":"$USER_GID" "$BACKUP_PATH"
fi

# Create .kube directory if it doesn't exist
echo "Creating .kube directory at $USER_KUBECONFIG_DIR..."
mkdir -p "$USER_KUBECONFIG_DIR"

# Copy kubeconfig and set permissions
echo "Copying K3s kubeconfig to $USER_KUBECONFIG_PATH..."
cp "$K3S_KUBECONFIG" "$USER_KUBECONFIG_PATH"

if [ $? -ne 0 ]; then
    echo "Error: Failed to copy kubeconfig file."
    exit 1
fi

echo "Setting ownership for the kubeconfig file..."
chown "$USER_UID":"$USER_GID" "$USER_KUBECONFIG_DIR"
chown "$USER_UID":"$USER_GID" "$USER_KUBECONFIG_PATH"

# Set permissions for the kubeconfig file (readable by user only)
chmod 600 "$USER_KUBECONFIG_PATH"

# Verify the configuration
echo ""
echo "=========================================="
echo "Configuration complete!"
echo "=========================================="
echo "User: $TARGET_USER"
echo "Kubeconfig: $USER_KUBECONFIG_PATH"
echo ""
echo "Testing kubectl access..."

# Test kubectl as the target user
su - "$TARGET_USER" -c "kubectl version --client --short 2>/dev/null"

if [ $? -eq 0 ]; then
    echo ""
    echo "kubectl is configured correctly!"
    echo ""
    echo "Next step: Run as $TARGET_USER (not root):"
    echo "  kubectl get nodes"
else
    echo ""
    echo "Warning: kubectl test failed. You may need to:"
    echo "  1. Open a new terminal session"
    echo "  2. Run: kubectl get nodes"
fi
