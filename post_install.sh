#!/bin/bash

# Exit on any error
set -e

echo "Starting post-installation tasks..."

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