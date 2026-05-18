# ArgoCD GitOps Setup Guide

## Overview

This project now uses **Terraform as the source of truth** for managing ArgoCD applications. All ArgoCD application manifests are stored in this repository under `argocd/`, while the actual Helm charts remain in the remote repository.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    This Repository                          │
│  (local-kubeadm - Source of Truth)                         │
│                                                             │
│  ├── terraform/bootstrap/                                  │
│  │   ├── main.tf          (Manages ArgoCD apps)           │
│  │   ├── variables.tf     (Git repo URL, PAT, revision)   │
│  │   └── terraform.tfvars (Your configuration)            │
│  │                                                          │
│  └── argocd/                                               │
│      ├── project.yaml      (AppProject definition)        │
│      └── apps/             (Application manifests)        │
│          ├── mariadb.yaml                                  │
│          ├── keystone.yaml                                 │
│          └── ...                                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Points to
                            ▼
┌─────────────────────────────────────────────────────────────┐
│           Remote Repository                                 │
│  (github.com/skyengpro/openstack-deployment)               │
│                                                             │
│  Branch: feat/deploy-neutron-agent-on-bare-metal...       │
│                                                             │
│  └── charts/                                               │
│      ├── mariadb-wrapper/                                  │
│      ├── keystone-wrapper/                                 │
│      ├── glance-wrapper/                                   │
│      └── ...                                               │
└─────────────────────────────────────────────────────────────┘
```

## Configuration Variables

### Terraform Variables (terraform/bootstrap/variables.tf)

| Variable | Description | Default |
|----------|-------------|---------|
| `gitops_repo_url` | Git repository URL (source of truth for charts) | `https://github.com/skyengpro/openstack-deployment.git` |
| `gitops_target_revision` | Git branch/tag/commit to use | `feat/deploy-neutron-agent-on-bare-metal-using-containers` |
| `github_pat` | GitHub Personal Access Token for private repos | `""` (empty for public repos) |

### Setting Up Configuration

1. **Copy the example configuration:**
   ```bash
   cd terraform/bootstrap
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars:**
   ```hcl
   # GitOps configuration
   gitops_repo_url        = "https://github.com/skyengpro/openstack-deployment.git"
   gitops_target_revision = "feat/deploy-neutron-agent-on-bare-metal-using-containers"
   
   # For private repositories, add your GitHub PAT
   github_pat = "ghp_your_token_here"
   ```

3. **Generate GitHub PAT (if needed):**
   - Go to: https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Select scope: `repo` (Full control of private repositories)
   - Copy the token and add it to `terraform.tfvars`

## Deployment

### Full Deployment

```bash
# Deploy everything (VMs, Kubernetes, ArgoCD, Applications)
make deploy
```

### Bootstrap Only (ArgoCD Applications)

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

This will:
1. Delete any existing ArgoCD applications not managed by Terraform
2. Apply the AppProject definition
3. Create the openstack namespace
4. Apply all application manifests from `argocd/apps/`

### Using Custom Kubeconfig

The deployment uses `~/.kube/config.local` by default. To use a different kubeconfig:

```bash
export KUBECONFIG=~/.kube/config.local
cd terraform/bootstrap
terraform apply
```

## ArgoCD Applications

All applications are deployed to the **openstack** namespace and use the **openstack** AppProject.

### Deployed Services

#### Storage & Infrastructure
- **rook-operator**: Rook Ceph operator
- **ceph-cluster**: Ceph storage cluster
- **haproxy-ingress**: HAProxy ingress controller
- **node-labeler**: Node labeling utility
- **node-route-manager**: Node routing management

#### Data Services
- **mariadb**: MySQL-compatible database
- **rabbitmq**: AMQP message broker
- **memcached**: In-memory caching

#### OpenStack Core Services
- **keystone**: Identity and authentication service
- **glance**: Image service
- **placement**: Resource placement service
- **nova**: Compute service
- **neutron**: Networking service
- **horizon**: Web dashboard

## Authentication for Private Repositories

When `github_pat` is provided, Terraform creates a Kubernetes secret in the ArgoCD namespace:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: openstack-repo-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: <gitops_repo_url>
  password: <github_pat>
  username: git
```

ArgoCD automatically discovers and uses this secret for authentication.

## Managing Applications

### Adding a New Application

1. **Create a new manifest in `argocd/apps/`:**
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-service
     namespace: argocd
     finalizers:
       - resources-finalizer.argocd.argoproj.io
   spec:
     project: openstack
     source:
       repoURL: https://github.com/skyengpro/openstack-deployment.git
       targetRevision: feat/deploy-neutron-agent-on-bare-metal-using-containers
       path: charts/my-service-wrapper
       helm:
         valueFiles:
           - values.yaml
     destination:
       server: https://kubernetes.default.svc
       namespace: openstack
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
         - CreateNamespace=true
   ```

2. **Apply the changes:**
   ```bash
   cd terraform/bootstrap
   terraform apply
   ```

### Removing an Application

1. **Delete the manifest file:**
   ```bash
   rm argocd/apps/my-service.yaml
   ```

2. **Apply the changes:**
   ```bash
   cd terraform/bootstrap
   terraform apply
   ```

### Changing Git Repository or Branch

1. **Update `terraform.tfvars`:**
   ```hcl
   gitops_repo_url        = "https://github.com/new-org/new-repo.git"
   gitops_target_revision = "main"
   ```

2. **Apply the changes:**
   ```bash
   cd terraform/bootstrap
   terraform apply
   ```

## Verification

### Check ArgoCD Applications

```bash
export KUBECONFIG=~/.kube/config.local
kubectl get applications -n argocd
```

### Check Application Status

```bash
kubectl get applications -n argocd -o wide
```

### Check Deployed Resources

```bash
kubectl get all -n openstack
```

### Access ArgoCD UI

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser to https://localhost:8080
# Username: admin
# Password: <from above command>
```

## Troubleshooting

### Applications Not Syncing

1. **Check ArgoCD logs:**
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
   ```

2. **Check repository secret:**
   ```bash
   kubectl get secret openstack-repo-secret -n argocd
   ```

3. **Manually sync an application:**
   ```bash
   kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{}}}'
   ```

### Authentication Issues

1. **Verify GitHub PAT is valid:**
   ```bash
   curl -H "Authorization: token $GITHUB_PAT" https://api.github.com/user
   ```

2. **Recreate the secret:**
   ```bash
   cd terraform/bootstrap
   terraform taint null_resource.ansible_provision
   terraform apply
   ```

### Terraform State Issues

1. **Check Terraform state:**
   ```bash
   cd terraform/bootstrap
   terraform state list
   ```

2. **Force recreation of ArgoCD apps:**
   ```bash
   terraform taint null_resource.openstack_argocd_apps
   terraform apply
   ```

## Best Practices

1. **Never commit `terraform.tfvars`** - It may contain sensitive PAT tokens
2. **Use branch protection** - Protect the main branch to prevent accidental changes
3. **Review changes** - Always run `terraform plan` before `terraform apply`
4. **Version control** - Commit all changes to `argocd/apps/` manifests
5. **Test in dev** - Test changes in a development environment first
6. **Monitor ArgoCD** - Regularly check ArgoCD UI for sync status

## Security Considerations

- GitHub PAT is stored in Terraform state (encrypted if using remote backend)
- PAT is also stored as a Kubernetes secret in the cluster
- Use least-privilege PAT with only `repo` scope
- Rotate PAT regularly
- Consider using ArgoCD's built-in SSO for production

## Migration Notes

This setup replaces the previous "App of Apps" pattern where ArgoCD managed itself. Now:

- ✅ Terraform is the source of truth
- ✅ All applications are explicitly defined in this repo
- ✅ Changes are version controlled and reviewable
- ✅ Terraform state tracks what's deployed
- ✅ Easy to add/remove applications
- ✅ Clear separation: manifests here, charts in remote repo
