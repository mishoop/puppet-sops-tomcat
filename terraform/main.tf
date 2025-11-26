# SSH Key
resource "hcloud_ssh_key" "puppet" {
  name       = "puppet-${var.environment}"
  public_key = file(var.ssh_public_key_path)
}

# Private Network
resource "hcloud_network" "puppet" {
  name     = "puppet-${var.environment}"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "puppet" {
  network_id   = hcloud_network.puppet.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

# Puppet Master
resource "hcloud_server" "puppet_master" {
  name        = "puppet-master"
  image       = "ubuntu-22.04"
  server_type = var.puppet_master_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.puppet.id]

  labels = {
    role        = "puppet-master"
    environment = var.environment
  }

  user_data = templatefile("${path.module}/templates/puppet-master-cloud-init.yaml", {
    puppet_master_ip = "10.0.1.10"
  })
}

resource "hcloud_server_network" "puppet_master" {
  server_id  = hcloud_server.puppet_master.id
  network_id = hcloud_network.puppet.id
  ip         = "10.0.1.10"
}

# Puppet Agents (Tomcat servers)
resource "hcloud_server" "puppet_agent" {
  count       = 2
  name        = "tomcat-${count.index + 1}"
  image       = "ubuntu-22.04"
  server_type = var.puppet_agent_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.puppet.id]

  labels = {
    role        = "tomcat"
    environment = var.environment
  }

  user_data = templatefile("${path.module}/templates/puppet-agent-cloud-init.yaml", {
    puppet_master_ip   = "10.0.1.10"
    puppet_master_fqdn = "puppet-master"
  })

  depends_on = [hcloud_server.puppet_master]
}

resource "hcloud_server_network" "puppet_agent" {
  count      = 2
  server_id  = hcloud_server.puppet_agent[count.index].id
  network_id = hcloud_network.puppet.id
  ip         = "10.0.1.${20 + count.index}"
}

# Firewall for Puppet Master
resource "hcloud_firewall" "puppet_master" {
  name = "puppet-master-fw"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "8140"
    source_ips = ["10.0.0.0/16"]
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "puppet_master" {
  firewall_id = hcloud_firewall.puppet_master.id
  server_ids  = [hcloud_server.puppet_master.id]
}

# Firewall for Tomcat Agents
resource "hcloud_firewall" "tomcat" {
  name = "tomcat-fw"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "8080"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "8443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "tomcat" {
  firewall_id = hcloud_firewall.tomcat.id
  server_ids  = hcloud_server.puppet_agent[*].id
}
