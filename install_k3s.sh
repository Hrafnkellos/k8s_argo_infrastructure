#!/bin/bash

# Exit on any error
set -e

echo "Starting k3s installation process..."

# Uninstall k3s if it exists
if command -v k3s &> /dev/null; then
    echo "Uninstalling existing k3s installation..."
    /usr/local/bin/k3s-uninstall.sh || true
fi

# Get the machine's IP address
MACHINE_IP=$(hostname -I | awk '{print $1}')
echo "Machine IP address: $MACHINE_IP"

# Install k3s
echo "Installing k3s..."
curl -sfL https://get.k3s.io | sh -

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
sleep 10

# Update kubeconfig with the correct IP
echo "Updating kubeconfig with machine IP..."
KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
if [ -f "$KUBECONFIG_PATH" ]; then
    # Create a copy of the kubeconfig in the user's home directory
    mkdir -p ~/.kube
    cp $KUBECONFIG_PATH ~/.kube/config
    
    # Update the server URL with the machine's IP
    sed -i "s/127.0.0.1/$MACHINE_IP/g" ~/.kube/config
    
    # Set proper permissions
    chmod 600 ~/.kube/config
    
    echo "Kubeconfig has been updated and copied to ~/.kube/config"
    echo "Current kubectl configuration:"
    echo "----------------------------------------"
    cat ~/.kube/config
    echo "----------------------------------------"
else
    echo "Error: k3s kubeconfig not found at $KUBECONFIG_PATH"
    exit 1
fi

echo "k3s installation and configuration completed successfully!" 