class hackerbot2::service{
  require hackerbot2::config

  file { '/etc/systemd/system/hackerbot2.service':
    ensure => 'link',
    target => '/opt/hackerbot2/hackerbot2.service',
  }->
  exec { 'hackerbot2-systemd-reload':
    command     => 'systemctl daemon-reload',
    path        => [ '/usr/bin', '/bin', '/usr/sbin' ],
    refreshonly => true,
  }->
  service { 'hackerbot2':
    ensure   => running,
    provider => systemd,
    enable   => true,
  }
}
