# Profile for Puppet Master server
# Manages r10k, SOPS setup, and code deployment

class profile_puppet_master (
  String $r10k_remote           = 'git@github.com:yourorg/puppet-control.git',
  String $r10k_basedir          = '/etc/puppetlabs/code/environments',
  Boolean $setup_sops           = true,
  String $sops_age_key_path     = '/etc/puppetlabs/puppet/sops/age-key.txt',
) {

  # Ensure git is installed for r10k
  package { 'git':
    ensure => present,
  }

  # Install r10k
  package { 'r10k':
    ensure   => present,
    provider => 'puppet_gem',
    require  => Package['git'],
  }

  # r10k configuration directory
  file { '/etc/puppetlabs/r10k':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # r10k configuration
  file { '/etc/puppetlabs/r10k/r10k.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile_puppet_master/r10k.yaml.epp', {
      'remote'  => $r10k_remote,
      'basedir' => $r10k_basedir,
    }),
    require => File['/etc/puppetlabs/r10k'],
  }

  # SOPS directory and key setup
  if $setup_sops {
    file { '/etc/puppetlabs/puppet/sops':
      ensure => directory,
      owner  => 'puppet',
      group  => 'puppet',
      mode   => '0700',
    }

    # Note: The age key should be generated during cloud-init
    # This just ensures the directory structure exists
    file { $sops_age_key_path:
      ensure  => file,
      owner   => 'puppet',
      group   => 'puppet',
      mode    => '0600',
      require => File['/etc/puppetlabs/puppet/sops'],
    }
  }

  # Deploy helper script
  file { '/usr/local/bin/puppet-deploy':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profile_puppet_master/puppet-deploy.sh',
  }

  # SOPS encrypt helper script
  file { '/usr/local/bin/sops-encrypt-secret':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profile_puppet_master/sops-encrypt-secret.sh',
  }
}
