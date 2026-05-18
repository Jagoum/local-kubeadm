# ArgoCD Configuration for OpenStack Deployment

This directory contains ArgoCD Application manifests for deploying OpenStack services.

## Structure

- `project.yaml`: ArgoCD AppProject definition for OpenStack
- `apps/`: Individual ArgoCD Application manifests for each OpenStack service

## Configuration

The Git repository and target revision are configured via Terraform variables:

- `gitops_repo_url`: Git repository URL (default: https://github.com/skyengpro/openstack-deployment.git)
- `gitops_target_revision`: Git branch/tag/commit (default: feat/deploy-neutron-agent-on-bare-metal-using-containers)
- `github_pat`: GitHub Personal Access Token for private repos (optional)

## Deployment

Applications are automatically deployed via Terraform:

```bash
cd terraform/bootstrap
terraform apply
```

## Manual Deployment

To manually apply the manifests:

```bash
export KUBECONFIG=~/.kube/config.local

# Apply AppProject
kubectl apply -f argocd/project.yaml

# Apply all applications
kubectl apply -f argocd/apps/
```

## Services Included

All services are deployed using **sync waves** to ensure proper dependency order. Storage is provided by **Longhorn** with the `openstack` StorageClass.

### Wave 0: Infrastructure & Data Services
- **mariadb**: Database service
- **rabbitmq**: Message broker
- **memcached**: Caching service
- **haproxy-ingress**: HAProxy ingress controller
- **node-labeler**: Node labeling utility
- **node-route-manager**: Node routing management

### Wave 1: Identity Service
- **keystone**: Identity service (foundation for all OpenStack services)

### Wave 2: Supporting Services
- **glance**: Image service
- **placement**: Placement API

### Wave 3: Networking
- **neutron**: Networking service

### Wave 4: Compute
- **nova**: Compute service

### Wave 5: Dashboard
- **horizon**: Web dashboard

See [SYNC_WAVES.md](SYNC_WAVES.md) for detailed deployment order and dependency information.

## Authentication

For private repositories, ArgoCD uses a Kubernetes secret created by Ansible:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: openstack-repo-secret
  namespace: argocd
type: Opaque
stringData:
  type: git
  url: <gitops_repo_url>
  password: <github_pat>
  username: git
```

All applications reference this secret for authentication.
