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
  kubectl apply -k base
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
