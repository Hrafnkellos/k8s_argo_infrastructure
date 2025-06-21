#!/bin/bash

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check if the argocd namespace exists
if ! kubectl get namespace argocd &> /dev/null; then
    echo "Error: argocd namespace not found"
    exit 1
fi

# Get and decode the ArgoCD admin password
echo "Retrieving ArgoCD admin password..."
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

if [ -z "$PASSWORD" ]; then
    echo "Error: Failed to retrieve password"
    exit 1
fi

echo "ArgoCD admin password:"
echo "----------------------"
echo "$PASSWORD"
echo "----------------------"
echo "Username: admin"
echo "URL: https://localhost:8080 (when port-forwarding is active)" 