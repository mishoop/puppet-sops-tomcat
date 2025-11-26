output "puppet_master_ip" {
  description = "Public IP of Puppet master"
  value       = hcloud_server.puppet_master.ipv4_address
}

output "puppet_master_private_ip" {
  description = "Private IP of Puppet master"
  value       = hcloud_server_network.puppet_master.ip
}

output "tomcat_ips" {
  description = "Public IPs of Tomcat servers"
  value       = hcloud_server.puppet_agent[*].ipv4_address
}

output "tomcat_private_ips" {
  description = "Private IPs of Tomcat servers"
  value       = hcloud_server_network.puppet_agent[*].ip
}

output "ssh_command_master" {
  description = "SSH command for Puppet master"
  value       = "ssh root@${hcloud_server.puppet_master.ipv4_address}"
}

output "ssh_commands_agents" {
  description = "SSH commands for Tomcat agents"
  value       = [for s in hcloud_server.puppet_agent : "ssh root@${s.ipv4_address}"]
}
