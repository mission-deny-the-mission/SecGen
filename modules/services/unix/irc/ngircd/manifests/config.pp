class ngircd::config {
  service { 'ngircd':
    enable   => true,
    ensure   => 'running',
    provider => systemd,
    require  => Package['ngircd'],
  }
}
