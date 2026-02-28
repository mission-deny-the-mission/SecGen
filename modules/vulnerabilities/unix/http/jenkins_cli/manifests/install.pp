# Class: jenkins_cli
# Install process for Jenkins cli
# https://github.com/rapid7/metasploit-framework/blob/master/documentation/modules/exploit/linux/http/jenkins_cli_deserialization.md
class jenkins_cli::install {
  Exec { path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ] }

  $secgen_parameters = secgen_functions::get_parameters($::base64_inputs_file)
  $user = $secgen_parameters['unix_username'][0]
  $port = $secgen_parameters['port'][0]

  $modulename = 'jenkins_cli'
  $releasename = 'jenkins.war'
  $splits = ["${releasename}.partaa",
  "${releasename}.partab"]

  $splits.each |String $split| {
    file { "/tmp/${split}":
      ensure => file,
      source => "puppet:///modules/${modulename}/${split}",
    }
  }

  # Archive.debian.org sources are now configured by unix_update module
  # Just ensure apt.conf.d settings are in place for this module
  file { '/etc/apt/apt.conf.d/99archive':
    ensure  => file,
    content => "Acquire::Check-Valid-Until \"false\";\nAcquire::Check-Date \"false\";\nAcquire::AllowInsecureRepositories \"true\";\n",
  }
  -> exec { 'update-packages':
    command => 'apt update'
  }
  -> package { 'install-jdk8':
    ensure => installed,
    name   => 'openjdk-8-jdk',
  }

  exec { 'rebuild-archive':
    cwd     => '/tmp/',
    command => "cat ${releasename}.parta* >/usr/local/bin/${releasename}",
  }
  -> file { '/etc/systemd/system/jenkins.service':
    content => template("${modulename}/jenkins.service.erb"),
    owner   => 'root',
    mode    => '0755',
  }
  -> service { 'jenkins':
    ensure => running,
    enable => true,
  }
}
