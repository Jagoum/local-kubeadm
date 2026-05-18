# Final OpenStack Deployment Guide

## Overview

This guide provides the complete, once-and-for-all solution to deploy OpenStack services with all issues resolved.

## Issues Fixed

### 1. ✅ MariaDB Multi-Attach & Split-Brain
**Problem**: All 3 MariaDB pods scheduled on single node causing volume conflicts

**Solution**:
- Added pod anti-affinity to spread pods across nodes
- Increased termination grace period to 60s for clean volume detachment
- Worker nodes will be labeled to allow pod distribution

### 2. ✅ Missing Bootstrap Jobs
**Problem**: Keystone, Glance, Placement, Nova, Horizon missing db-init/db-sync jobs

**Solution**:
- Added Helm parameter overrides to enable all required jobs
- Jobs will be created automatically by ArgoCD

### 3. ✅ Keystone Fernet/Credential Keys
**Problem**: Secrets not created, pods stuck waiting

**Solution**:
- Secrets already created manually
- ArgoCD configured to ignore these secrets (won't delete them)
- Fernet/credential setup jobs disabled (keys already exist)

## Complete Deployment

### Prerequisites

1. Kubernetes cluster running
2. Longhorn storage with `openstack` StorageClass
3. `~/.kube/config.local` kubeconfig file
4. Terraform and kubectl installed

### One-Command Deployment

```bash
./scripts/deploy-openstack-complete.sh
```

This script will:
1. ✅ Label worker nodes for MariaDB HA
2. ✅ Apply all ArgoCD applications via Terraform
3. ✅ Wait for MariaDB cluster to be healthy
4. ✅ Monitor Keystone deployment
5. ✅ Show overall sync status

### Manual Deployment Steps

If you prefer to run steps manually:

#### Step 1: Label Worker Nodes

```bash
export KUBECONFIG=~/.kube/config.local

# Label worker nodes
kubectl label node worker-1 openstack-role=control-plane --overwrite
kubectl label node worker-2 openstack-role=control-plane --overwrite
```

#### Step 2: Apply Terraform

```bash
cd terraform/bootstrap
terraform apply
```

#### Step 3: Monitor Deployment

```bash
# Watch ArgoCD applications
kubectl get applications -n argocd -w

# Watch pods
kubectl get pods -n openstack -w

# Check MariaDB cluster
kubectl exec mariadb-server-0 -n openstack -c mariadb -- \
  mariadb -uroot -ppassword -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
```

## Application Configuration

All applications now have proper Helm parameter overrides:

### MariaDB
```yaml
parameters:
  - name: "pod.replicas.server"
    value: "3"
  - name: "pod.affinity.anti_affinity"
    value: "required"
  - name: "pod.lifecycle.termination_grace_period.server"
    value: "60"
```

### Keystone
```yaml
parameters:
  - name: "jobs.db_init.enabled"
    value: "true"
  - name: "jobs.db_sync.enabled"
    value: "true"
  - name: "jobs.bootstrap.enabled"
    value: "true"
  - name: "jobs.fernet_setup.enabled"
    value: "false"  # Already created manually
  - name: "jobs.credential_setup.enabled"
    value: "false"  # Already created manually
```

### Glance, Placement, Nova, Horizon
```yaml
parameters:
  - name: "jobs.db_init.enabled"
    value: "true"
  - name: "jobs.db_sync.enabled"
    value: "true"
  - name: "jobs.ks_user.enabled"
    value: "true"
  - name: "jobs.ks_service.enabled"
    value: "true"
  - name: "jobs.ks_endpoints.enabled"
    value: "true"
```

## Deployment Order (Sync Waves)

Services deploy in this order:

```
Wave 0: Infrastructure
  ├── mariadb (3 replicas, spread across nodes)
  ├── rabbitmq
  ├── memcached
  ├── haproxy-ingress
  ├── node-labeler
  └── node-route-manager

Wave 1: Identity
  └── keystone (with db-init, db-sync, bootstrap jobs)

Wave 2: Supporting Services
  ├── glance (with all jobs)
  └── placement (with all jobs)

Wave 3: Networking
  └── neutron

Wave 4: Compute
  └── nova (with all jobs including cell_setup)

Wave 5: Dashboard
  └── horizon (with db jobs)
```

## Verification

### Check All Applications

```bash
kubectl get applications -n argocd
```

Expected output:
```
NAME                SYNC STATUS   HEALTH STATUS
mariadb             Synced        Healthy
rabbitmq            Synced        Healthy
memcached           Synced        Healthy
haproxy-ingress     Synced        Healthy
node-labeler        Synced        Healthy
node-route-manager  Synced        Healthy
keystone            Synced        Healthy
glance              Synced        Healthy
placement           Synced        Healthy
neutron             Synced        Healthy
nova                Synced        Healthy
horizon             Synced        Healthy
```

### Check All Pods

```bash
kubectl get pods -n openstack
```

All pods should be `Running` and `Ready`.

### Check MariaDB Cluster

```bash
kubectl exec mariadb-server-0 -n openstack -c mariadb -- \
  mariadb -uroot -ppassword -e "SHOW STATUS LIKE 'wsrep_%';"
```

Look for:
- `wsrep_cluster_size = 3`
- `wsrep_local_state_comment = Synced`
- `wsrep_ready = ON`

### Check Keystone

```bash
kubectl exec -n openstack deployment/keystone-api -- \
  openstack --os-auth-url http://keystone-api:5000/v3 \
  --os-project-name admin --os-username admin \
  --os-password password token issue
```

Should return a valid token.

## Troubleshooting

### MariaDB Pods Not Spreading

**Symptom**: All MariaDB pods on same node

**Solution**:
```bash
# Check node labels
kubectl get nodes --show-labels | grep openstack-role

# If missing, label nodes
kubectl label node worker-1 openstack-role=control-plane
kubectl label node worker-2 openstack-role=control-plane

# Restart pods to trigger rescheduling
kubectl delete pod mariadb-server-1 mariadb-server-2 -n openstack
```

### Jobs Not Running

**Symptom**: Pods stuck in Init, waiting for jobs

**Solution**:
```bash
# Check if jobs exist
kubectl get jobs -n openstack -l application=keystone

# If missing, sync the application
kubectl patch application keystone -n argocd --type merge -p '{"operation":{"sync":{}}}'

# Or re-apply via Terraform
cd terraform/bootstrap && terraform apply
```

### Keystone API Not Starting

**Symptom**: Keystone pods stuck waiting for secrets

**Solution**:
```bash
# Check if secrets exist
kubectl get secrets -n openstack | grep keystone | grep -E "fernet|credential"

# If missing, recreate them (see docs/KEYSTONE_BOOTSTRAP_ISSUE.md)
```

### Volume Attachment Errors

**Symptom**: `Multi-Attach error for volume`

**Solution**:
```bash
# Force delete stuck pod
kubectl delete pod <pod-name> -n openstack --force --grace-period=0

# Wait for volume to detach (30-60 seconds)
sleep 60

# Pod will be recreated automatically
```

## Maintenance

### Scaling MariaDB

To change MariaDB replicas:

1. Edit `argocd/apps/mariadb.yaml`:
   ```yaml
   - name: "pod.replicas.server"
     value: "3"  # Change this
   ```

2. Apply:
   ```bash
   cd terraform/bootstrap && terraform apply
   ```

### Updating Service Configuration

To change any service configuration:

1. Edit the application file in `argocd/apps/<service>.yaml`
2. Add or modify Helm parameters
3. Apply via Terraform:
   ```bash
   cd terraform/bootstrap && terraform apply
   ```

### Changing Git Repository or Branch

Edit `terraform/bootstrap/terraform.tfvars`:
```hcl
gitops_repo_url        = "https://github.com/your-org/your-repo.git"
gitops_target_revision = "your-branch"
```

Then apply:
```bash
cd terraform/bootstrap && terraform apply
```

## Best Practices

1. **Always use Terraform** to apply changes (GitOps way)
2. **Never manually edit resources** that ArgoCD manages
3. **Monitor ArgoCD sync status** before making changes
4. **Test in development** before applying to production
5. **Keep worker nodes labeled** for proper pod distribution
6. **Review logs** when services fail to start
7. **Use sync waves** to ensure proper deployment order

## Success Criteria

✅ All ArgoCD applications show `Synced` and `Healthy`  
✅ All pods in `openstack` namespace are `Running` and `Ready`  
✅ MariaDB cluster has 3 nodes, all `Synced`  
✅ Keystone API responds to authentication requests  
✅ All services registered in Keystone catalog  
✅ No pods stuck in `Init`, `Pending`, or `CrashLoopBackOff`  

## Support

For issues:
1. Check logs: `kubectl logs -n openstack <pod-name>`
2. Check events: `kubectl get events -n openstack --sort-by='.lastTimestamp'`
3. Review documentation in `docs/` directory
4. Check ArgoCD UI for detailed sync information

## References

- [ArgoCD Sync Waves](argocd/SYNC_WAVES.md)
- [MariaDB Issue Analysis](MARIADB_ISSUE_ANALYSIS.md)
- [Keystone Bootstrap Issue](KEYSTONE_BOOTSTRAP_ISSUE.md)
- [Deployment Summary](DEPLOYMENT_SUMMARY.md)
