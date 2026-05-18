# ArgoCD Sync Waves Strategy

## Overview

Sync waves control the order in which ArgoCD deploys applications. Lower wave numbers are deployed first, and ArgoCD waits for each wave to be healthy before proceeding to the next.

## Storage Backend

This deployment uses **Longhorn** as the storage backend with the `openstack` StorageClass. Rook/Ceph is not required.

## Deployment Order

### Wave 0: Infrastructure & Data Services (Parallel)
- **mariadb** - Database service (OpenStack services depend on this)
- **rabbitmq** - Message broker (OpenStack services depend on this)
- **memcached** - Caching service (OpenStack services depend on this)
- **haproxy-ingress** - Ingress controller for external access
- **node-labeler** - Labels nodes for proper scheduling
- **node-route-manager** - Manages node routing

*These can deploy in parallel as they don't depend on each other*

### Wave 1: Identity Service (Core)
- **keystone** - Identity service (all other OpenStack services depend on this)

### Wave 2: Supporting Services (Parallel)
- **glance** - Image service (depends on keystone)
- **placement** - Placement API (depends on keystone)

*These can deploy in parallel as they only depend on keystone*

### Wave 3: Networking Service
- **neutron** - Networking service (depends on keystone, needed by nova)

### Wave 4: Compute Service
- **nova** - Compute service (depends on keystone, placement, neutron, glance)

### Wave 5: Dashboard
- **horizon** - Web dashboard (depends on all other services being available)

## Dependency Graph

```
Wave 0: mariadb, rabbitmq, memcached, haproxy-ingress, node-labeler, node-route-manager
          │
          ▼
Wave 1: keystone (Identity)
          │
          ├─────────┬─────────┐
          ▼         ▼         ▼
Wave 2: glance  placement  (parallel)
          │         │
          └────┬────┘
               ▼
Wave 3:    neutron
               │
               ▼
Wave 4:      nova
               │
               ▼
Wave 5:    horizon
```

## Benefits

1. **Ordered Deployment**: Services deploy in the correct dependency order
2. **Automatic Waiting**: ArgoCD waits for each wave to be healthy before proceeding
3. **Failure Isolation**: If a service in wave N fails, wave N+1 won't deploy
4. **Parallel Deployment**: Services in the same wave deploy concurrently
5. **Predictable Behavior**: Consistent deployment order every time

## Sync Wave Annotations

Each application has the sync wave annotation in its metadata:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keystone
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"  # Deploy in wave 3
```

## Health Checks

ArgoCD considers an application healthy when:
- All pods are running
- All services are available
- All health checks pass

Only then does it proceed to the next wave.

## Manual Sync

If you need to manually sync a specific application:

```bash
# Sync a specific app
kubectl patch application keystone -n argocd --type merge -p '{"operation":{"sync":{}}}'

# Sync all apps (respects sync waves)
kubectl patch application -n argocd --all --type merge -p '{"operation":{"sync":{}}}'
```

## Troubleshooting

### Application Stuck in Wave

If an application is stuck and blocking the next wave:

1. **Check application status:**
   ```bash
   kubectl get application <app-name> -n argocd -o yaml
   ```

2. **Check application health:**
   ```bash
   kubectl get application <app-name> -n argocd -o jsonpath='{.status.health.status}'
   ```

3. **Check sync status:**
   ```bash
   kubectl get application <app-name> -n argocd -o jsonpath='{.status.sync.status}'
   ```

4. **View application resources:**
   ```bash
   kubectl get all -n openstack -l app.kubernetes.io/instance=<app-name>
   ```

### Skip Waiting for Health

If you need to force deployment to continue (not recommended):

```yaml
syncPolicy:
  syncOptions:
    - SkipDryRunOnMissingResource=true
```

## Modifying Sync Waves

To change the deployment order:

1. Edit the application manifest in `argocd/apps/<app-name>.yaml`
2. Change the `argocd.argoproj.io/sync-wave` annotation value
3. Apply changes via Terraform:
   ```bash
   cd terraform/bootstrap
   terraform apply
   ```

## Best Practices

1. **Use gaps between waves** - Leave room for future services (e.g., 0, 2, 4, 6 instead of 0, 1, 2, 3)
2. **Group independent services** - Services that don't depend on each other should be in the same wave
3. **Test the order** - Verify deployment order works in a test environment first
4. **Monitor health** - Watch ArgoCD UI during deployment to catch issues early
5. **Document dependencies** - Keep this file updated when adding new services

## References

- [ArgoCD Sync Waves Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [ArgoCD Resource Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)
