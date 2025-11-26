# Main site manifest

# Default node - fail safely
node default {
  notify { 'Unknown node':
    message => "Node ${trusted['certname']} is not configured in Puppet",
  }
}

# Puppet master node
node /^puppet-master/ {
  include profile_puppet_master
}

# Tomcat application servers
node /^tomcat-\d+/ {
  include profile_tomcat
}
