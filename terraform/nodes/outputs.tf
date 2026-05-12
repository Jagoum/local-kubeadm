output "control_plane_ip" {
  value = multipass_instance.control_plane.ipv4[0]
}

output "control_plane_id" {
  value = multipass_instance.control_plane.id
}

output "worker_ips" {
  value = [for w in multipass_instance.workers : w.ipv4[0]]
}

output "worker_ids" {
  value = [for w in multipass_instance.workers : w.id]
}
