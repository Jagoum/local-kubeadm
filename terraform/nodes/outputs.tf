output "control_plane_ip" {
  value = incus_instance.control_plane.ipv4_address
}

output "control_plane_id" {
  value = incus_instance.control_plane.name
}

output "worker_ips" {
  value = [for w in incus_instance.workers : w.ipv4_address]
}

output "worker_ids" {
  value = [for w in incus_instance.workers : w.name]
}
