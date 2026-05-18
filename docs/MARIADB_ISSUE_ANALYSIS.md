# MariaDB Multi-Attach Issue - Root Cause Analysis

## Issue Summary

MariaDB StatefulSet pods (mariadb-server-1 and mariadb-server-2) were stuck in `Init:0/2` or `Terminating` state with the error:

```
Multi-Attach error for volume "pvc-xxx" Volume is already exclusively attached to one node and can't be attached to another
```

## Root Cause

The issue occurred due to a **combination of factors**:

### 1. **Single Control Plane Node Constraint**

All MariaDB pods have the node selector:
```yaml
nodeSelector:
  openstack-role: control-plane
```

Your cluster has:
- **1 control-plane node** (10.253.137.140)
- **2 worker nodes** (worker-1, worker-2)

**Problem**: All 3 MariaDB pods (mariadb-server-0, mariadb-server-1, mariadb-server-2) are trying to schedule on the **same single control-plane node**.

### 2. **RWO (ReadWriteOnce) Volumes**

The PVCs use `accessMode: RWO` (ReadWriteOnce), which means:
- Each volume can only be attached to **one node at a time**
- Multiple pods on the **same node** can share the volume
- Pods on **different nodes** cannot share the volume

**This is correct for StatefulSets** - each pod needs its own dedicated volume.

### 3. **Longhorn Volume Attachment Delay**

When pods are rescheduled or restarted:
1. Pod is terminated
2. Longhorn needs to **detach the volume** from the node
3. New pod tries to start
4. Volume is still attached to the old pod (grace period)
5. **Multi-Attach error occurs**

### 4. **Galera Cluster Split-Brain Protection**

MariaDB Galera cluster has built-in split-brain protection:
- When pods restart, they check cluster state
- If quorum is lost, pods wait for manual intervention
- This compounds the volume attachment issue

## Why It Happened

The most likely trigger was:

1. **Pod Eviction or Restart**: Something caused mariadb-server-1 and mariadb-server-2 to restart
   - Could be: resource pressure, node maintenance, manual restart, or ArgoCD sync

2. **Graceful Termination Delay**: Pods entered `Terminating` state but didn't fully terminate
   - Longhorn volumes remained attached during grace period (default 30s)

3. **New Pods Scheduled**: New pods tried to start on the same node
   - Volumes were still attached to old pods
   - Multi-Attach error occurred

4. **Cascading Failure**: 
   - mariadb-server-1 stuck in Terminating
   - mariadb-server-2 stuck in Init (waiting for volume)
   - Galera cluster lost quorum (only 1/3 nodes healthy)
   - Split-brain protection kicked in

## Why Single Node Scheduling?

All MariaDB pods are constrained to the control-plane node because:

```yaml
nodeSelector:
  openstack-role: control-plane
```

**Checking your nodes:**
```bash
$ kubectl get nodes --show-labels | grep openstack-role
control-plane   openstack-role=control-plane
worker-1        (no openstack-role label)
worker-2        (no openstack-role label)
```

Only the control-plane node has the `openstack-role=control-plane` label, so all 3 MariaDB pods must run on that single node.

## Why This Is a Problem

### Single Point of Failure
- All database pods on one node
- If that node fails, entire database cluster is down
- No high availability benefit from 3 replicas

### Resource Contention
- 3 MariaDB pods competing for resources on one node
- Control plane workloads also on same node
- Potential CPU/memory pressure

### Volume Attachment Issues
- Multiple pods restarting on same node
- Longhorn volume detach/attach delays
- Race conditions during pod rescheduling

## Solutions

### Option 1: Label Worker Nodes (Recommended)

Allow MariaDB to spread across all nodes:

```bash
# Label worker nodes
kubectl label node worker-1 openstack-role=control-plane
kubectl label node worker-2 openstack-role=control-plane

# Or use a different label strategy
kubectl label node worker-1 openstack-role=data
kubectl label node worker-2 openstack-role=data
kubectl label node control-plane openstack-role=data

# Update MariaDB chart values to use the new label
nodeSelector:
  openstack-role: data
```

**Benefits:**
- True high availability (pods on different nodes)
- Better resource distribution
- Reduced volume attachment conflicts

### Option 2: Use Pod Anti-Affinity

Ensure pods spread across nodes even if they have the same label:

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: application
          operator: In
          values:
          - mariadb
      topologyKey: kubernetes.io/hostname
```

**Benefits:**
- Forces pods to different nodes
- Prevents all pods on single node
- Better fault tolerance

### Option 3: Reduce Replicas to 1

If you must run on a single node:

```bash
kubectl scale statefulset mariadb-server -n openstack --replicas=1
```

**Benefits:**
- No multi-attach issues
- Simpler deployment
- Lower resource usage

**Drawbacks:**
- No high availability
- Single point of failure
- No automatic failover

### Option 4: Increase Grace Period

Give Longhorn more time to detach volumes:

```yaml
terminationGracePeriodSeconds: 60  # Default is 30
```

**Benefits:**
- Reduces race conditions
- Allows clean volume detachment

**Drawbacks:**
- Slower pod restarts
- Doesn't solve root cause

## Recommended Action

**For Production**: Use Option 1 + Option 2

1. **Label all nodes** to allow scheduling across cluster
2. **Add pod anti-affinity** to ensure distribution
3. **Increase grace period** to 60 seconds

This provides:
- ✅ True high availability
- ✅ Fault tolerance
- ✅ Better resource utilization
- ✅ Reduced volume conflicts

## Current State

After recovery:
- ✅ MariaDB running with 1 replica (mariadb-server-0)
- ✅ Cluster is healthy and synced
- ✅ No volume attachment issues

**To scale back to 3 replicas:**
```bash
kubectl scale statefulset mariadb-server -n openstack --replicas=3
```

**Note**: This will likely cause the same issue unless you implement one of the solutions above.

## Prevention

To prevent this in the future:

1. **Monitor pod events**: Watch for evictions and restarts
2. **Check node resources**: Ensure adequate CPU/memory
3. **Review node labels**: Ensure proper distribution
4. **Test failover**: Regularly test pod restarts
5. **Use pod disruption budgets**: Limit concurrent disruptions

## References

- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Longhorn Volume Attachment](https://longhorn.io/docs/latest/volumes-and-nodes/volume-attachment/)
- [MariaDB Galera Cluster](https://mariadb.com/kb/en/galera-cluster/)
- [Pod Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
