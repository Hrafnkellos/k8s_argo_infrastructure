# ArgoCD Repository Template

This repository contains a template for managing Kubernetes applications using ArgoCD with a structured approach for different environments: test, staging, and production.

## argocd get password

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Kustomize

<https://github.com/kubernetes-sigs/kustomize>

## Project Structure

The project is organized into the following directories:

- **base**: Contains the base Kubernetes resources that are common across all environments.
  - `deployment.yaml`: Defines the Kubernetes deployment resource.
  - `service.yaml`: Defines the Kubernetes service resource.
  - `kustomization.yaml`: Kustomize configuration for the base resources.

- **overlays**: Contains environment-specific customizations.
  - **test**: Customizations for the test environment.
    - `kustomization.yaml`: Kustomize configuration for the test environment.
    - `values.yaml`: Configuration values specific to the test environment.
  - **staging**: Customizations for the staging environment.
    - `kustomization.yaml`: Kustomize configuration for the staging environment.
    - `values.yaml`: Configuration values specific to the staging environment.
  - **production**: Customizations for the production environment.
    - `kustomization.yaml`: Kustomize configuration for the production environment.
    - `values.yaml`: Configuration values specific to the production environment.

## Kubernetes setup

![alt text](kubernets_flow.png)

## Getting Started

1. **Clone the Repository**

   ```bash
   git clone <repository-url>
   ```

2. **Install environment**
  
  ```bash
  # setup default
  kubectl apply -k base

  # setup dev environment
  kubectl apply -k overlays/test
  ```

3. **Customize Your Environment**
   - Modify the `values.yaml` files in the respective environment overlays to suit your configuration needs.

4. **Deploying with ArgoCD**
   - Ensure you have ArgoCD installed and configured in your Kubernetes cluster.
   - Create an ArgoCD application pointing to the desired overlay (test, staging, or production).

## Managing Secrets with Sealed Secrets

This project uses [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to securely store encrypted secrets in Git. Sealed Secrets allows you to encrypt your Kubernetes Secrets so they can be safely stored in a public repository.

### Prerequisites

1. **Install kubeseal CLI**

   ```bash
   # For Linux
   wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.1/kubeseal-0.24.1-linux-amd64.tar.gz
   tar -xzf kubeseal-0.24.1-linux-amd64.tar.gz
   sudo mv kubeseal /usr/local/bin/

   # For macOS
   brew install kubeseal
   ```

2. **Verify Installation**
   ```bash
   kubeseal --version
   ```

### Using Sealed Secrets

1. **Create a regular Kubernetes secret**
   ```bash
   # Create a secret (don't apply it)
   kubectl create secret generic my-secret \
     --from-literal=username=admin \
     --from-literal=password=secret123 \
     --dry-run=client -o yaml > secret.yaml
   ```

2. **Encrypt the secret**
   ```bash
   # Seal the secret
   kubeseal --format yaml < secret.yaml > sealed-secret.yaml
   ```

3. **Apply the sealed secret**
   ```bash
   kubectl apply -f sealed-secret.yaml
   ```

4. **Verify the secret**
   ```bash
   # The sealed secret should be created
   kubectl get sealedsecrets
   
   # The actual secret should be automatically unsealed
   kubectl get secrets
   ```

### Best Practices

- Never commit unencrypted secrets to Git
- Store sealed secrets in your repository
- Use different sealed secrets for different environments
- Rotate secrets periodically
- Use meaningful names for your secrets that indicate their purpose

## Artifactory OSS

This project includes JFrog Artifactory OSS, a universal artifact repository manager. Artifactory OSS is the open-source version that provides essential artifact management capabilities.

### Features

- Universal artifact repository (supports multiple package types)
- Built-in PostgreSQL database
- Nginx reverse proxy
- Persistent storage for artifacts and database
- Resource limits and requests configured for optimal performance

### Accessing Artifactory

After deployment, Artifactory will be available within the cluster at:
- Artifactory: `http://artifactory-oss-artifactory.artifactory:8082`
- Nginx: `http://artifactory-oss-nginx.artifactory:80`

### Initial Setup

1. **Get the initial admin password**
   ```bash
   kubectl -n artifactory get secret artifactory-oss-artifactory -o jsonpath="{.data.artifactory\.password}" | base64 -d
   ```

2. **Access the web interface**
   - The default username is `admin`
   - Use the password obtained from the previous step

### Managing Artifactory Secrets

The PostgreSQL password is managed using Sealed Secrets. To update it:

1. **Create a new secret**
   ```bash
   kubectl create secret generic artifactory-postgresql \
     --from-literal=postgresql-password=your-new-password \
     --dry-run=client -o yaml > base/artifactory/secrets/postgres-secret.yaml
   ```

2. **Seal the secret**
   ```bash
   kubeseal --format yaml < base/artifactory/secrets/postgres-secret.yaml > base/artifactory/secrets/sealed-postgres-secret.yaml
   ```

3. **Apply the sealed secret**
   ```bash
   kubectl apply -f base/artifactory/secrets/sealed-postgres-secret.yaml
   ```

### Best Practices

- Regularly backup your Artifactory data
- Monitor storage usage
- Keep Artifactory updated to the latest stable version
- Use appropriate resource limits based on your usage
- Implement proper access controls and user management

## Contributing

Feel free to submit issues or pull requests for improvements or additional features.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Sealed Secret (Bitbucket Repository) Template

This section describes how to create (or reseal) a sealed secret (for example, for your Bitbucket repository) using the provided seal-secret.sh script.

### Prerequisites

• kubeseal (installed (e.g. via brew or from the sealed–secrets release))  
• A running sealed–secrets controller (so that you can fetch the public cert)  
• An unsealed secret (template) (for example, “bitbucket-repo.yaml”) (see below)

### Unsealed Secret Template (Example)

Below is an example (unsealed) secret (for example, “bitbucket-repo.yaml”) (for ArgoCD’s repository secret) that you can use as a template. (Replace sensitive values (like your SSH private key) as needed.)

```yaml
# (Example: overlays/test/sealed-secrets/bitbucket-repo.yaml)
apiVersion: v1
kind: Secret
metadata:
  name: bitbucket-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: git@bitbucket.org:rldevrldev/rl-kubeinfrastructure.git
  sshPrivateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    (your SSH private key (or token) goes here)
    -----END OPENSSH PRIVATE KEY-----
  insecure: "true"  # (Optional) Skip host key verification (if needed)
```

### Resealing (or Generating) the Sealed Secret

1. (Optional) Ensure that your unsealed secret (template) (for example, “bitbucket-repo.yaml”) is present (for example, in “overlays/test/sealed-secrets”).  
2. Run the seal-secret.sh script (located in “scripts/”) (after making it executable (e.g. chmod +x scripts/seal-secret.sh)).  
   • (The script checks (or fetches) the sealed–secrets controller’s public cert (from “pub-cert.pem”) and then seals your unsealed secret (using kubeseal) into “overlays/test/sealed-secrets/sealed-bitbucket-repo.yaml”.)  
3. (Optional) (If you uncomment the “kubectl apply” line in seal-secret.sh) the sealed secret is applied automatically.  
   • (Otherwise, you can apply it manually (e.g. “kubectl apply –f overlays/test/sealed-secrets/sealed-bitbucket-repo.yaml”).)

### Notes

• (If you reset (or delete) your cluster, the sealed–secrets controller’s private key (and hence the sealed secret) will be lost. In that case, reinstall sealed–secrets (so that a new private key is generated) and then re-run seal-secret.sh (or reseal your secret) so that it can be unsealed in the new cluster.)  
• (Always ensure that your unsealed secret (template) (for example, “bitbucket-repo.yaml”) is not committed (or pushed) (so that sensitive data (like your SSH private key) is not exposed).)
