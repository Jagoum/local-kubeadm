# Keystone Bootstrap Issue

## Problem Summary

Keystone and dependent services (Glance, Placement, Nova, Horizon) are failing to start due to missing initialization jobs and secrets.

## Root Cause

The `keystone-wrapper` chart in the remote repository is missing or not properly configured to create:

1. **Fernet and Credential Keys** - Required secrets for Keystone token encryption
2. **Database Initialization Jobs** - `keystone-db-init` and `keystone-db-sync` jobs

## What We Did

### ✅ Created Missing Secrets Manually

Successfully created the required secrets:
- `keystone-fernet-keys` - Fernet encryption keys for tokens
- `keystone-credential-keys` - Credential encryption keys

**Method Used:**
```bash
# Created temporary pod with keystone image
# Generated keys using keystone-manage commands
# Created secrets from generated keys
```

**Verification:**
```bash
$ kubectl get secrets -n openstack | grep keystone | grep -E "fernet|credential"
keystone-credential-keys   Opaque   2      Created
keystone-fernet-keys       Opaque   2      Created
```

### ❌ Missing Database Jobs

The chart is not creating the required database initialization jobs:
- `keystone-db-init` - Creates keystone database and user
- `keystone-db-sync` - Runs database migrations

**Evidence:**
```bash
$ kubectl logs keystone-api-xxx -c init
Entrypoint WARNING: Resolving dependency Job keystone-db-sync in namespace openstack failed: 
jobs.batch "keystone-db-sync" not found
```

## Current State

### Working
- ✅ Fernet keys created
- ✅ Credential keys created
- ✅ Keystone ServiceAccounts, Roles, RoleBindings created
- ✅ Keystone Services and Ingress created
- ✅ Keystone CronJobs for key rotation created

### Not Working
- ❌ Keystone API pods stuck in Init (waiting for db-sync job)
- ❌ Glance pods stuck (waiting for Keystone)
- ❌ Placement pods stuck (waiting for Keystone)
- ❌ Nova pods stuck (waiting for Keystone)
- ❌ Horizon pods stuck (waiting for Keystone)

## Chart Configuration Issue

The `keystone-wrapper` chart in the remote repository needs to be configured to:

1. **Enable Bootstrap Jobs**
   ```yaml
   jobs:
     db_init:
       enabled: true
     db_sync:
       enabled: true
     bootstrap:
       enabled: true
   ```

2. **Configure Fernet/Credential Setup**
   ```yaml
   conf:
     keystone:
       fernet_tokens:
         key_repository: /etc/keystone/fernet-keys/
       credential:
         key_repository: /etc/keystone/credential-keys/
   ```

3. **Ensure Job Dependencies**
   - db-init should run before db-sync
   - db-sync should run before API pods
   - bootstrap should run after db-sync

## Workaround Options

### Option 1: Fix the Chart (Recommended)

Update the `keystone-wrapper` chart in the remote repository:
- Enable all required jobs
- Configure proper dependencies
- Ensure secrets are created by the chart

### Option 2: Manual Bootstrap (Temporary)

Manually create the missing jobs:

```bash
# Create db-init job
kubectl create job keystone-db-init -n openstack \
  --image=docker.io/openstackhelm/keystone:2024.1-ubuntu_jammy \
  -- /tmp/db-init.sh

# Create db-sync job  
kubectl create job keystone-db-sync -n openstack \
  --image=docker.io/openstackhelm/keystone:2024.1-ubuntu_jammy \
  -- /tmp/db-sync.sh
```

**Note:** This requires the scripts to be available in the image or mounted via ConfigMap.

### Option 3: Use Different Chart

Switch to a different Keystone chart that properly handles bootstrap:
- OpenStack-Helm official charts
- Kolla-Kubernetes charts
- Custom wrapper with proper bootstrap

## Impact on Other Services

All OpenStack services depend on Keystone for authentication:

```
Keystone (Identity)
  ├── Glance (Image Service)
  ├── Placement (Placement API)
  ├── Nova (Compute)
  ├── Neutron (Networking)
  └── Horizon (Dashboard)
```

**Until Keystone is working:**
- No service can authenticate
- No API endpoints can be registered
- No users/projects can be created
- OpenStack is non-functional

## Recommended Action

1. **Check Remote Repository**
   - Review `charts/keystone-wrapper/values.yaml`
   - Verify job configurations
   - Check if jobs are disabled

2. **Enable Jobs in Values**
   - If jobs exist but are disabled, enable them
   - Update ArgoCD application to use custom values

3. **Or Fix Chart**
   - Add missing job templates
   - Configure proper dependencies
   - Test in development environment

4. **Sync ArgoCD**
   - Once chart is fixed, sync the application
   - Jobs should run automatically
   - Keystone should start successfully

## Verification Steps

After fixing the chart:

```bash
# 1. Check jobs are created
kubectl get jobs -n openstack | grep keystone

# 2. Verify jobs completed
kubectl get jobs -n openstack -l application=keystone

# 3. Check Keystone pods
kubectl get pods -n openstack -l application=keystone

# 4. Verify Keystone API is responding
kubectl exec -n openstack keystone-api-xxx -- keystone-manage doctor

# 5. Test authentication
kubectl exec -n openstack keystone-api-xxx -- \
  openstack --os-auth-url http://keystone-api:5000/v3 \
  --os-project-name admin --os-username admin \
  --os-password password token issue
```

## References

- [OpenStack-Helm Keystone Chart](https://github.com/openstack/openstack-helm/tree/master/keystone)
- [Keystone Bootstrap Documentation](https://docs.openstack.org/keystone/latest/admin/bootstrap.html)
- [Fernet Tokens](https://docs.openstack.org/keystone/latest/admin/fernet-token-faq.html)

## Status

**Current**: Keystone bootstrap incomplete - missing database initialization jobs

**Next Steps**: Fix the `keystone-wrapper` chart in the remote repository to include all required bootstrap jobs
