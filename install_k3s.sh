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

# Install Traefik Middleware CRD if not present
# if ! k3s kubectl get crd middlewares.traefik.io &>/dev/null; then
#     echo "Installing Traefik Middleware CRD..."
#     k3s kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.10/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
# else
#     echo "Traefik Middleware CRD already installed."
# fi

# Apply the base configuration
echo "Applying base configuration..."
k3s kubectl apply -k overlays/test || echo "Warning: Failed to apply base configuration, continuing with post-installation tasks..."
k3s kubectl apply -k overlays/test || echo "Warning: Failed to apply base configuration, continuing with post-installation tasks..."

# Function to get and print credentials
print_credentials() {
    local namespace=$1
    local secret_name=$2
    local secret_key=$3
    local service_name=$4
    local path=$5

    echo -e "\n=== $service_name Credentials ==="
    echo "----------------------------------------"
    echo "URL: http://192.168.45.238$path"
    echo "Username: admin"
    echo -n "Password: "
    k3s kubectl -n $namespace get secret $secret_name -o jsonpath="{.data.$secret_key}" | base64 -d
    echo -e "\n----------------------------------------"
}

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
k3s kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get and print ArgoCD credentials
# k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
print_credentials "argocd" "argocd-initial-admin-secret" "password" "ArgoCD" "/argocd"

# Wait for Jenkins to be ready
echo "Waiting for Jenkins to be ready..."
k3s kubectl wait --for=condition=available --timeout=300s deployment/jenkins -n jenkins

# Get and print Jenkins credentials
print_credentials "jenkins" "jenkins" "jenkins-admin-password" "Jenkins" "/jenkins"

echo -e "\nPost-installation tasks completed successfully!"
echo "You can now access:"
echo "- ArgoCD at http://192.168.45.238/argocd"
echo "- Jenkins at http://192.168.45.238/jenkins" 



echo "k3s installation and configuration completed" 