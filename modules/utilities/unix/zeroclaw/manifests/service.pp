# ZeroClaw Service Management
# Manages the ZeroClaw systemd service

class zeroclaw::service {
  # Install systemd service file
  file { '/etc/systemd/system/zeroclaw.service':
    ensure  => file,
    source  => 'puppet:///modules/zeroclaw/zeroclaw.service',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Exec['zeroclaw-systemd-reload'],
  }

  # Reload systemd daemon when service file changes
  exec { 'zeroclaw-systemd-reload':
    command     => 'systemctl daemon-reload',
    path        => ['/usr/bin', '/bin', '/usr/sbin'],
    refreshonly => true,
  }

  # Enable and start ZeroClaw service
  service { 'zeroclaw':
    ensure   => running,
    enable   => true,
    provider => systemd,
    require  => [
      File['/etc/systemd/system/zeroclaw.service'],
      File['/opt/zeroclaw/zeroclaw'],
    ],
  }

  # Ensure IRC server is running for ZeroClaw
  service { 'inspircd':
    ensure  => running,
    enable  => true,
    require => Package['inspircd'],
  }
}
