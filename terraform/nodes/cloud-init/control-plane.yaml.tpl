#cloud-config
# Cloud-init configuration for control plane node
# Production-grade setup with optimized kernel parameters

# Set hostname
hostname: ${hostname}
manage_etc_hosts: true

# SSH configuration
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin, sudo
    shell: /bin/bash
    lock_passwd: false
    password: ${node_password}
    ssh_authorized_keys:
%{ if ssh_public_key != "" ~}
      - ${ssh_public_key}
%{ else ~}
      - # No Default Key, Must Bring Your Key 
%{ endif ~}

# Package management
package_update: true
package_upgrade: true

# Install essential packages
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - software-properties-common
  - jq
  - htop
  - vim
  - net-tools
  - openssh-server

# Kernel and system tuning for Kubernetes
write_files:
  - path: /etc/sysctl.d/99-kubernetes.conf
    content: |
      # Network tuning for production
      net.bridge.bridge-nf-call-iptables = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward = 1
      net.ipv4.conf.all.forwarding = 1
      net.ipv4.conf.default.forwarding = 1
      
      # TCP tuning for high throughput
      net.core.somaxconn = 32768
      net.ipv4.tcp_max_syn_backlog = 32768
      net.core.netdev_max_backlog = 32768
      net.ipv4.tcp_fin_timeout = 30
      net.ipv4.tcp_keepalive_time = 300
      net.ipv4.tcp_keepalive_probes = 5
      net.ipv4.tcp_keepalive_intvl = 15
      
      # Memory management
      vm.max_map_count = 262144
      vm.swappiness = 10
      
      # File descriptors
      fs.file-max = 2097152
      fs.inotify.max_user_instances = 8192
      fs.inotify.max_user_watches = 524288

  - path: /etc/security/limits.d/99-kubernetes.conf
    content: |
      * soft nofile 65536
      * hard nofile 65536
      * soft nproc 65536
      * hard nproc 65536
      root soft nofile 65536
      root hard nofile 65536

  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter

# Run commands for initial setup
runcmd:
  # Load kernel modules
  - modprobe overlay
  - modprobe br_netfilter
  
  # Apply sysctl settings
  - sysctl --system
  
  # Disable swap (required for Kubernetes)
  - swapoff -a
  - sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  
  # Configure containerd prerequisites
  - mkdir -p /etc/containerd
  
  # Set up kernel modules persistence
  - echo "overlay" >> /etc/modules
  - echo "br_netfilter" >> /etc/modules

# Final message
final_message: "Control plane node ${hostname} setup complete! System uptime: $UPTIME seconds"