# Local Kubernetes Cluster with Kubeadm

Production-grade Kubernetes cluster deployment using Terraform and Ansible on Incus VMs with Calico CNI.

## 🏗️ Architecture

This project provisions a production-ready Kubernetes cluster with the following specifications:

- **Control Plane Node**: 2 vCPU, 4GB RAM, 20GB disk
- **Worker Nodes**: 2 vCPU, 3GB RAM, 40GB disk (x2)
- **Container Runtime**: Containerd 2.0+ with SystemdCgroup
- **CNI**: Calico v3.31.x (supports Kubernetes 1.32-1.34)
- **Kubernetes Version**: 1.34 (stable, supported until Oct 2026)
- **OS**: Ubuntu 24.04 LTS

## 📋 Prerequisites

### Required Software

- **Terraform** >= 1.0.0
- **Incus** >= 6.0 (installed and configured)
- **Python** >= 3.9 (with venv module)
- **Make** (usually pre-installed on Linux/macOS)

### Python Virtual Environment

This project uses a Python3 virtual environment to isolate Ansible and its dependencies. The Makefile handles setup automatically.

### SSH Key (Optional)

Generate an SSH key pair for VM access:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k8s_cluster_key
```

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd local-kubeadm
```

### 2. Deploy Infrastructure (One Command)

The easiest way to deploy is using the Makefile, which handles everything:

```bash
make deploy
```

This will:
1. Create a Python3 virtual environment (`.venv/`)
2. Install Ansible in the virtual environment
3. Install required Ansible collections
4. Initialize Terraform
5. Apply Terraform to create VMs and run Ansible

### 3. Manual Step-by-Step Deployment

If you prefer to run each step manually:

```bash
# Create virtual environment and install Ansible
make install-ansible

# Install Ansible collections
make install-collections

# Initialize and apply Terraform
make init
make plan  # Optional: review changes
make apply
```

### 4. Activate Virtual Environment (Optional)

To run Ansible commands manually, activate the virtual environment first:

```bash
source .venv/bin/activate
ansible-playbook -i ansible/inventory/hosts.ini ansible/site.yml
```

Or use the Makefile targets which automatically use the virtual environment:

```bash
make ansible-run
```

### 5. Verify Deployment

```bash
# Access control plane
incus exec k8s-control-plane -- sudo -i -u ubuntu

# Verify cluster status
sudo kubectl get nodes -o wide
sudo kubectl get pods --all-namespaces
```

## 📁 Project Structure

```
local-kubeadm/
├── terraform/
│   ├── bootstrap/                 # Ansible inventory generation & orchestration
│   ├── nodes/                     # VM provisioning (Incus)
│   │   ├── main.tf                # Main Terraform configuration
│   │   ├── variables.tf           # Terraform variables
│   │   ├── outputs.tf             # Terraform outputs
│   │   └── cloud-init/
│       ├── control-plane.yaml.tpl # Control plane cloud-init
│       └── worker.yaml.tpl        # Worker node cloud-init
├── ansible/
│   ├── ansible.cfg                # Ansible configuration
│   ├── requirements.yml           # Ansible collections
│   ├── site.yml                   # Main playbook
│   ├── inventory/
│   │   └── hosts.ini              # Inventory (auto-generated)
│   ├── group_vars/
│   │   ├── all.yml                # Global variables
│   │   ├── control_plane.yml      # Control plane variables
│   │   └── workers.yml            # Worker node variables
│   └── roles/
│       ├── common/                # Common prerequisites
│       ├── containerd/            # Container runtime
│       ├── kubernetes/            # Kubernetes packages
│       ├── control-plane/         # Control plane setup
│       ├── worker/                # Worker node setup
│       └── calico/                # Calico CNI
└── README.md
```

## ⚙️ Configuration

### Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `control_plane_name` | Control plane node name | `k8s-control-plane` |
| `worker_names` | Worker node names | `["k8s-worker-1", "k8s-worker-2"]` |
| `ubuntu_image` | Ubuntu image version | `24.04` |
| `kubernetes_version` | Kubernetes version | `1.34` (stable) |
| `calico_version` | Calico CNI version | `3.31.x` |
| `pod_network_cidr` | Pod network CIDR | `10.244.0.0/16` |
| `service_cidr` | Service network CIDR | `10.96.0.0/12` |

### Ansible Variables

Key variables in [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml:1):

```yaml
kubernetes_version: "1.34"  # Stable version (supported until Oct 2026)
calico_version: "3.31"      # Supports Kubernetes 1.32-1.34
pod_network_cidr: "10.244.0.0/16"  # Safe for Multipass
service_cidr: "10.96.0.0/12"
containerd_version: "2.0"  # containerd 2.x series
```

## 🔧 Manual Ansible Deployment

If you want to run Ansible separately from Terraform, first ensure the virtual environment is set up:

```bash
# Create venv and install Ansible (if not already done)
make install-ansible

# Install collections
make install-collections
```

Then run Ansible using the Makefile targets:

```bash
# Run full playbook
make ansible-run

# Or activate the venv and run manually
source .venv/bin/activate
cd ansible
ansible-playbook -i inventory/hosts.ini site.yml
```

### Run Specific Tags

```bash
# Using Makefile
make ansible-tags TAGS=common
make ansible-tags TAGS=containerd
make ansible-tags TAGS=control-plane
make ansible-tags TAGS=worker

# Or with activated venv
source .venv/bin/activate
cd ansible
ansible-playbook -i inventory/hosts.ini site.yml --tags common
ansible-playbook -i inventory/hosts.ini site.yml --tags containerd
ansible-playbook -i inventory/hosts.ini site.yml --tags control-plane
ansible-playbook -i inventory/hosts.ini site.yml --tags worker
```

## 🎯 Production Features

### Security Hardening

- ✅ SystemdCgroup enabled for containerd
- ✅ Kernel parameters optimized for Kubernetes
- ✅ Swap disabled
- ✅ Pod Security Policies enabled
- ✅ RBAC authorization mode
- ✅ Node restriction admission plugin

### Performance Optimizations

- ✅ Kernel tuning for high throughput
- ✅ System limits configured
- ✅ TCP optimizations
- ✅ Memory management tuned
- ✅ File descriptor limits increased

### Resource Management

- ✅ Resource quotas configured
- ✅ Eviction policies set
- ✅ System and kube reservations
- ✅ Pod limits enforced

## 📊 Cluster Verification

### Check Node Status

```bash
kubectl get nodes -o wide
```

### Check System Pods

```bash
kubectl get pods -n kube-system
```

### Check Calico Installation

```bash
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl get ippools
```

### Check Component Status

```bash
kubectl get cs
```

## 🔍 Troubleshooting

### Common Issues

#### 1. VMs Not Starting

```bash
# Check Incus status
incus list

# Check VM details
incus info k8s-control-plane
```

#### 2. Ansible Connection Issues

```bash
# Test SSH connectivity
ssh ubuntu@<VM_IP> -o StrictHostKeyChecking=no

# Check inventory
ansible-inventory -i inventory/hosts.ini --list
```

#### 3. Kubernetes Cluster Issues

```bash
# Check kubelet status
sudo systemctl status kubelet

# Check kubelet logs
sudo journalctl -u kubelet -f

# Check containerd status
sudo systemctl status containerd
```

#### 4. Calico CNI Issues

```bash
# Check Calico logs
kubectl logs -n kube-system -l k8s-app=calico-node

# Check Calico configuration
kubectl get ippools
kubectl get felixconfigurations
```

### Reset Cluster

```bash
# On all nodes
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd
sudo rm -rf /etc/cni/net.d

# Re-run Ansible
ansible-playbook -i inventory/hosts.ini site.yml
```

## 🧹 Cleanup

### Destroy Infrastructure

```bash
cd terraform/nodes
terraform destroy
cd ../bootstrap
terraform destroy
```

### Manual Cleanup

```bash
# Delete VMs
incus delete -f k8s-control-plane k8s-worker-1 k8s-worker-2
```

## 📝 Customization

### Add Worker Nodes

1. Edit [`terraform/variables.tf`](terraform/variables.tf:1):

```hcl
variable "worker_names" {
  default = ["k8s-worker-1", "k8s-worker-2", "k8s-worker-3"]
}
```

2. Apply changes:

```bash
terraform apply
```

### Change VM Specifications

Edit [`terraform/main.tf`](terraform/main.tf:1):

```hcl
resource "incus_instance" "control_plane" {
  config = {
    "limits.cpu"    = 4      # Increase CPU
    "limits.memory" = "8GiB"  # Increase memory
  }
  device {
    name = "root"
    type = "disk"
    properties = {
      size = "50GiB"   # Increase disk
    }
  }
}
```

### Use Different Kubernetes Version

Edit [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml:1):

```yaml
kubernetes_version: "1.34"  # Stable version (supported until Oct 2026)
```

## 📌 Version Information (2026)

### Supported Kubernetes Versions
| Version | Status | EOL Date |
|---------|--------|----------|
| 1.36 | Latest | Just released |
| 1.35 | Stable | Active |
| **1.34** | **Stable** | **Oct 2026** |
| 1.33 | Maintenance | Jun 2026 |
| 1.32 | EOL | Feb 2026 |
| 1.31 | EOL | Oct 2025 |

### Supported Calico Versions
| Version | Status | EOL Date |
|---------|--------|----------|
| 3.32 | Latest | Active |
| **3.31** | **Stable** | **Supports K8s 1.32-1.34** |
| 3.30 | Stable | Mar 2026 |

### Container Runtime
- **containerd 2.0+**: LTS release (supported until Mar 2027)
- SystemdCgroup required for Kubernetes 1.24+

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Kubernetes Documentation
- Calico Documentation
- Terraform Multipass Provider
- Ansible Kubernetes Collection

## 📚 References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Calico Documentation](https://docs.projectcalico.org/)
- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Terraform Incus Provider](https://registry.terraform.io/providers/lxc/incus/)
- [Ansible Kubernetes Collection](https://galaxy.ansible.com/kubernetes/core)

## 📧 Support

For issues and feature requests, please create an issue in the repository.