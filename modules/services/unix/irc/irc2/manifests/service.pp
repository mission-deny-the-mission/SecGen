class irc2::service {
  service { 'ngircd':
    enable   => true,
    ensure   => 'running',
    provider => systemd,
    require  => Package['ngircd'],
  }
}
