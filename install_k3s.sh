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

# Get current user and group
CURRENT_USER=$(whoami)
CURRENT_GROUP=$(id -gn)

# Install k3s with proper configuration
echo "Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san $MACHINE_IP --write-kubeconfig-mode=0644 --write-kubeconfig-group=$CURRENT_GROUP" sh -

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
sleep 10

# Update kubeconfig with the correct IP
echo "Updating kubeconfig with machine IP..."
KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"

# if the kubeconfig file does not exist, exit
[ ! -f "$KUBECONFIG_PATH" ] && echo "Error: k3s kubeconfig not found at $KUBECONFIG_PATH" && exit 1

# Ensure proper permissions on the k3s.yaml file
sudo chmod 644 $KUBECONFIG_PATH
sudo chown root:$CURRENT_GROUP $KUBECONFIG_PATH

# Debug: Show the current server URL
echo "Current server URL in kubeconfig:"
sudo grep "server:" $KUBECONFIG_PATH

# Update the server URL with the machine's IP (handle both 127.0.0.1 and 0.0.0.0)
echo "Replacing IP addresses with $MACHINE_IP..."
sudo sed -i "s|https://127.0.0.1:6443|https://$MACHINE_IP:6443|g" $KUBECONFIG_PATH
sudo sed -i "s|https://0.0.0.0:6443|https://$MACHINE_IP:6443|g" $KUBECONFIG_PATH

# Debug: Show the new server URL
echo "New server URL in kubeconfig:"
sudo grep "server:" $KUBECONFIG_PATH

echo "Kubeconfig has been updated"

# Print kubeconfig for Lens
echo -e "\n=== KUBECONFIG FOR LENS (COPY BELOW THIS LINE) ==="
echo "----------------------------------------"
sudo cat $KUBECONFIG_PATH 
echo -e "\n----------------------------------------"
echo "=== END OF KUBECONFIG ==="


echo "k3s installation and configuration completed" 