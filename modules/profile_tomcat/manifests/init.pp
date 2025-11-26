# Profile for Tomcat application servers
# Manages Tomcat installation and configuration with secrets from SOPS

class profile_tomcat (
  # Tomcat configuration
  String $version                    = '9',
  Integer $http_port                 = 8080,
  Integer $https_port                = 8443,
  Integer $ajp_port                  = 8009,
  Integer $shutdown_port             = 8005,
  String $java_home                  = '/usr/lib/jvm/java-17-openjdk-amd64',
  String $java_opts                  = '-Xms512m -Xmx1024m',

  # Application configuration
  String $app_name                   = 'myapp',
  Optional[String] $app_war_source   = undef,

  # Database credentials (from SOPS-encrypted Hiera)
  Optional[String] $db_username      = undef,
  Optional[String] $db_password      = undef,
  Optional[String] $db_url           = undef,

  # Additional secrets
  Optional[String] $api_key          = undef,
  Optional[String] $api_secret       = undef,
  Optional[String] $keystore_password = undef,
  Optional[String] $session_secret   = undef,

  # Datasource configuration hash
  Optional[Hash] $datasource_config  = undef,
) {

  $catalina_home = "/opt/tomcat${version}"
  $catalina_base = "/opt/tomcat${version}"

  # Ensure Java is installed (should be from cloud-init, but ensure it's there)
  package { 'openjdk-17-jdk':
    ensure => present,
  }

  # Create tomcat user and group
  group { 'tomcat':
    ensure => present,
    system => true,
  }

  user { 'tomcat':
    ensure     => present,
    gid        => 'tomcat',
    home       => $catalina_home,
    shell      => '/bin/false',
    system     => true,
    managehome => false,
    require    => Group['tomcat'],
  }

  # Download and extract Tomcat
  $tomcat_version_full = $version ? {
    '9'     => '9.0.83',
    '10'    => '10.1.16',
    default => '9.0.83',
  }

  $tomcat_archive = "apache-tomcat-${tomcat_version_full}"
  $tomcat_url = "https://archive.apache.org/dist/tomcat/tomcat-${version}/v${tomcat_version_full}/bin/${tomcat_archive}.tar.gz"

  archive { "/tmp/${tomcat_archive}.tar.gz":
    ensure       => present,
    source       => $tomcat_url,
    extract      => true,
    extract_path => '/opt',
    creates      => "/opt/${tomcat_archive}",
    cleanup      => true,
    require      => Package['openjdk-17-jdk'],
  }

  file { $catalina_home:
    ensure  => link,
    target  => "/opt/${tomcat_archive}",
    require => Archive["/tmp/${tomcat_archive}.tar.gz"],
  }

  # Set ownership
  exec { 'chown-tomcat':
    command     => "chown -R tomcat:tomcat /opt/${tomcat_archive}",
    path        => ['/bin', '/usr/bin'],
    refreshonly => true,
    subscribe   => Archive["/tmp/${tomcat_archive}.tar.gz"],
  }

  # Configure server.xml
  file { "${catalina_home}/conf/server.xml":
    ensure  => file,
    owner   => 'tomcat',
    group   => 'tomcat',
    mode    => '0640',
    content => epp('profile_tomcat/server.xml.epp', {
      'http_port'     => $http_port,
      'https_port'    => $https_port,
      'ajp_port'      => $ajp_port,
      'shutdown_port' => $shutdown_port,
    }),
    notify  => Service['tomcat'],
    require => File[$catalina_home],
  }

  # Configure context.xml with secrets
  file { "${catalina_home}/conf/context.xml":
    ensure  => file,
    owner   => 'tomcat',
    group   => 'tomcat',
    mode    => '0640',
    content => epp('profile_tomcat/context.xml.epp', {
      'db_username'       => $db_username,
      'db_password'       => $db_password,
      'db_url'            => $db_url,
      'api_key'           => $api_key,
      'api_secret'        => $api_secret,
      'session_secret'    => $session_secret,
      'datasource_config' => $datasource_config,
    }),
    notify  => Service['tomcat'],
    require => File[$catalina_home],
  }

  # Configure setenv.sh
  file { "${catalina_home}/bin/setenv.sh":
    ensure  => file,
    owner   => 'tomcat',
    group   => 'tomcat',
    mode    => '0750',
    content => epp('profile_tomcat/setenv.sh.epp', {
      'java_home' => $java_home,
      'java_opts' => $java_opts,
    }),
    notify  => Service['tomcat'],
    require => File[$catalina_home],
  }

  # Systemd service file
  file { '/etc/systemd/system/tomcat.service':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile_tomcat/tomcat.service.epp', {
      'catalina_home' => $catalina_home,
      'java_home'     => $java_home,
    }),
    notify  => [Exec['systemctl-daemon-reload'], Service['tomcat']],
  }

  exec { 'systemctl-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  # Manage Tomcat service
  service { 'tomcat':
    ensure  => running,
    enable  => true,
    require => [
      File['/etc/systemd/system/tomcat.service'],
      File["${catalina_home}/conf/server.xml"],
      File["${catalina_home}/conf/context.xml"],
      User['tomcat'],
      Exec['systemctl-daemon-reload'],
    ],
  }

  # Deploy application WAR if specified
  if $app_war_source {
    file { "${catalina_home}/webapps/${app_name}.war":
      ensure  => file,
      owner   => 'tomcat',
      group   => 'tomcat',
      mode    => '0644',
      source  => $app_war_source,
      notify  => Service['tomcat'],
      require => File[$catalina_home],
    }
  }
}
