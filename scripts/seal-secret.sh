#!/bin/bash

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
  echo "kubeseal not found. Please install it (e.g. via brew or download from the sealed-secrets release)."
  exit 1
fi

# Check if SSH key name is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <ssh-key-name> [namespace] [repo-url]"
  echo "Example: $0 bitbucket-infra-key argocd git@bitbucket.org:your-org/your-repo.git"
  exit 1
fi

SSH_KEY_NAME="$1"
NAMESPACE="${2:-argocd}"
REPO_URL="${3:-git@bitbucket.org:rldevrldev/rl-kubeinfrastructure.git}"

# Check if the SSH key exists
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "SSH key not found at $SSH_KEY_PATH"
  exit 1
fi

# Create the secret template directory if it doesn't exist
SECRET_DIR="overlays/test/sealed-secrets"
mkdir -p "$SECRET_DIR"

# Create the unsealed secret template
UNSEALED_SECRET_FILE="$SECRET_DIR/bitbucket-repo.yaml"
cat > "$UNSEALED_SECRET_FILE" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: bitbucket-repo
  namespace: $NAMESPACE
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: $REPO_URL
  sshPrivateKey: |
$(cat "$SSH_KEY_PATH" | sed 's/^/    /')
  insecure: "true"
EOF

echo "Created secret template at $UNSEALED_SECRET_FILE"

# Fetch or use existing public cert
PUB_CERT_FILE="pub-cert.pem"
if [ ! -f "$PUB_CERT_FILE" ]; then
  echo "Public cert (pub-cert.pem) not found. Fetching from sealed-secrets controller..."
  kubeseal --fetch-cert > "$PUB_CERT_FILE"
fi

# Seal the secret
SEALED_SECRET_FILE="$SECRET_DIR/sealed-bitbucket-repo.yaml"
echo "Sealing secret..."
kubeseal --format yaml --cert="$PUB_CERT_FILE" < "$UNSEALED_SECRET_FILE" > "$SEALED_SECRET_FILE"
echo "Sealed secret written to $SEALED_SECRET_FILE"

# Clean up the unsealed secret
rm "$UNSEALED_SECRET_FILE"
echo "Removed unsealed secret template for security"

# Optional: Apply the sealed secret
read -p "Do you want to apply the sealed secret now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  kubectl apply -f "$SEALED_SECRET_FILE"
  echo "Applied sealed secret to cluster"
fi 