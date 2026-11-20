class hackerbot3::service{
  require hackerbot3::config

  file { '/etc/systemd/system/hackerbot3.service':
    ensure => 'link',
    target => '/opt/hackerbot3/hackerbot3.service',
  }->
  exec { 'hackerbot3-systemd-reload':
    command     => 'systemctl daemon-reload',
    path        => [ '/usr/bin', '/bin', '/usr/sbin' ],
    refreshonly => true,
  }->
  service { 'hackerbot3':
    ensure   => running,
    provider => systemd,
    enable   => true,
  }
}
