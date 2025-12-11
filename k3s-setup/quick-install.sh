#!/bin/bash

# Quick K3s Installation Script
# This script runs both install and configure steps in sequence

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "K3s Quick Installation"
echo "=========================================="
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root.${NC}"
    echo "Usage: sudo ./quick-install.sh"
    exit 1
fi

# Check if K3s is already installed
if command -v k3s >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: K3s appears to be already installed.${NC}"
    echo ""
    read -p "Do you want to reinstall? This will remove the existing installation. (yes/no): " -r
    echo ""

    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Uninstalling existing K3s..."
        if [ -f "$SCRIPT_DIR/uninstall-k3s.sh" ]; then
            bash "$SCRIPT_DIR/uninstall-k3s.sh"
        else
            echo -e "${RED}Error: uninstall-k3s.sh not found${NC}"
            exit 1
        fi
    else
        echo "Installation cancelled."
        exit 0
    fi
fi

# Step 1: Install K3s
echo ""
echo "=========================================="
echo "Step 1: Installing K3s"
echo "=========================================="
echo ""

if [ ! -f "$SCRIPT_DIR/install-k3s.sh" ]; then
    echo -e "${RED}Error: install-k3s.sh not found in $SCRIPT_DIR${NC}"
    exit 1
fi

bash "$SCRIPT_DIR/install-k3s.sh"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: K3s installation failed${NC}"
    exit 1
fi

# Wait a bit for K3s to stabilize
echo ""
echo "Waiting for K3s to stabilize..."
sleep 5

# Step 2: Configure kubectl
echo ""
echo "=========================================="
echo "Step 2: Configuring kubectl"
echo "=========================================="
echo ""

if [ ! -f "$SCRIPT_DIR/configure-k3s.sh" ]; then
    echo -e "${RED}Error: configure-k3s.sh not found in $SCRIPT_DIR${NC}"
    exit 1
fi

bash "$SCRIPT_DIR/configure-k3s.sh"

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Warning: kubectl configuration encountered issues${NC}"
    echo "You may need to configure it manually."
fi

# Step 3: Final verification
echo ""
echo "=========================================="
echo "Step 3: Verifying Installation"
echo "=========================================="
echo ""

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
TIMEOUT=60
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if kubectl get nodes --no-headers 2>/dev/null | grep -q "Ready"; then
        echo -e "${GREEN}Cluster is ready!${NC}"
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done

echo ""

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${YELLOW}Warning: Cluster did not become ready within ${TIMEOUT} seconds${NC}"
    echo "Check the status with: sudo systemctl status k3s"
else
    echo ""
    echo "Cluster nodes:"
    kubectl get nodes

    echo ""
    echo "System pods:"
    kubectl get pods -A
fi

# Summary
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo -e "${GREEN}K3s has been successfully installed and configured.${NC}"
echo ""
echo "Useful commands:"
echo "  kubectl get nodes              # Show cluster nodes"
echo "  kubectl get pods -A            # Show all pods"
echo "  sudo systemctl status k3s      # Check K3s service status"
echo "  sudo journalctl -u k3s -f      # View K3s logs"
echo ""
echo "Logs are available at:"
echo "  /var/log/k3s-install.log"
echo ""
echo "Next steps:"
echo "  1. Install NGINX Ingress Controller (cd ../infrastructure/ingress-nginx)"
echo "  2. Install Cert-Manager for TLS certificates (cd ../certs)"
echo "  3. Deploy your applications"
echo ""
