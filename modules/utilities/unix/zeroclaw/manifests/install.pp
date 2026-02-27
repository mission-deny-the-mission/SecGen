# ZeroClaw Installation
# Installs ZeroClaw binary, IRC server, and dependencies

class zeroclaw::install {
  # Create ZeroClaw directories
  file { '/opt/zeroclaw':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/opt/zeroclaw/hackerbot':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }

  file { '/opt/zeroclaw/workspace':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/var/lib/zeroclaw':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/var/log/zeroclaw':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Install ZeroClaw binary from Puppet files
  file { '/opt/zeroclaw/zeroclaw':
    ensure => file,
    source => 'puppet:///modules/zeroclaw/zeroclaw',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    require => File['/opt/zeroclaw'],
  }

  # Create symlink for easier access
  file { '/usr/local/bin/zeroclaw':
    ensure => link,
    target => '/opt/zeroclaw/zeroclaw',
    require => File['/opt/zeroclaw/zeroclaw'],
  }

  # Install IRC server (inspircd)
  package { 'inspircd':
    ensure => installed,
  }

  # Configure IRC server
  file { '/etc/inspircd/inspircd.conf':
    ensure  => file,
    source  => 'puppet:///modules/zeroclaw/ircd.conf',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Service['inspircd'],
    require => Package['inspircd'],
  }

  # Enable and start IRC server
  service { 'inspircd':
    ensure   => running,
    enable   => true,
    require  => Package['inspircd'],
  }

  # Install Ollama (if not already installed)
  # Note: In production, you may want to manage Ollama separately
  package { 'ollama':
    ensure   => installed,
    provider => 'appimage',  # Or use custom provider
  }

  # Ensure Ollama models are available
  exec { 'ollama-pull-gemma3':
    command     => 'ollama pull gemma3:1b',
    path        => ['/usr/bin', '/bin', '/usr/sbin'],
    unless      => 'ollama list | grep -q gemma3',
    require     => Package['ollama'],
  }

  exec { 'ollama-pull-nomic-embed':
    command     => 'ollama pull nomic-embed-text',
    path        => ['/usr/bin', '/bin', '/usr/sbin'],
    unless      => 'ollama list | grep -q nomic-embed',
    require     => Package['ollama'],
  }
}
