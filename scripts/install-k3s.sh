#!/usr/bin/env bash
# Install single-node K3s and bootstrap Argo CD from this repo.
#
# After this runs, Argo CD syncs overlays/test (see base/argocd/application.yaml)
# and deploys everything else from git.
#
# Usage:
#   sudo ./scripts/install-k3s.sh
#
# Optional environment variables:
#   K3S_VERSION         pin a K3s release, e.g. v1.34.1+k3s1 (default: stable channel)
#   SKIP_K3S=1          skip the K3s install (cluster already running)
#   TB_POSTGRES_PASSWORD, TB_KEYCLOAK_ADMIN_PASSWORD
#                       passwords for the travelbooking secret; generated if unset
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run as root (sudo $0)"
command -v curl >/dev/null || die "curl is required"

# ── 1. K3s ──────────────────────────────────────────────────────────────────
if [[ "${SKIP_K3S:-0}" != "1" ]]; then
  log "Installing K3s ${K3S_VERSION:-(stable channel)}"
  curl -sfL https://get.k3s.io \
    | INSTALL_K3S_VERSION="${K3S_VERSION:-}" sh -s - --write-kubeconfig-mode 644
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl() { /usr/local/bin/kubectl "$@"; }

log "Waiting for the node to become Ready"
for _ in $(seq 1 60); do
  kubectl get nodes 2>/dev/null | grep -q ' Ready' && break
  sleep 5
done
kubectl wait --for=condition=Ready node --all --timeout=120s

# kubeconfig for the invoking (non-root) user
install -d -m 700 -o "$TARGET_USER" "$TARGET_HOME/.kube"
install -m 600 -o "$TARGET_USER" "$KUBECONFIG" "$TARGET_HOME/.kube/config"

# ── 2. Secrets that are deliberately not in git ─────────────────────────────
gen() { head -c 24 /dev/urandom | base64 | tr -d '/+=' ; }

if ! kubectl get namespace travelbooking >/dev/null 2>&1; then
  kubectl create namespace travelbooking
fi
if ! kubectl -n travelbooking get secret travelbooking-secrets >/dev/null 2>&1; then
  log "Creating travelbooking-secrets"
  kubectl -n travelbooking create secret generic travelbooking-secrets \
    --from-literal=POSTGRES_PASSWORD="${TB_POSTGRES_PASSWORD:-$(gen)}" \
    --from-literal=KEYCLOAK_ADMIN=admin \
    --from-literal=KEYCLOAK_ADMIN_PASSWORD="${TB_KEYCLOAK_ADMIN_PASSWORD:-$(gen)}"
else
  log "travelbooking-secrets already exists, leaving it alone"
fi

# ── 3. Argo CD ──────────────────────────────────────────────────────────────
# Server-side apply: the Argo CD CRDs are too large for client-side apply's
# last-applied annotation. The first pass may fail on the Application because
# its CRD isn't established yet; wait for it, then apply again.
log "Installing Argo CD"
kubectl apply --server-side --force-conflicts -k "$REPO_ROOT/base/argocd" || true
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=120s
kubectl apply --server-side --force-conflicts -k "$REPO_ROOT/base/argocd"

log "Waiting for Argo CD to come up"
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s

# ── Done ────────────────────────────────────────────────────────────────────
log "Done"
cat <<EOF
Argo CD is syncing overlays/test from git.

  kubectl -n argocd get applications
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
  kubectl -n argocd port-forward svc/argocd-server 8443:443   # https://localhost:8443

Keycloak admin password:
  kubectl -n travelbooking get secret travelbooking-secrets -o jsonpath='{.data.KEYCLOAK_ADMIN_PASSWORD}' | base64 -d; echo
EOF
