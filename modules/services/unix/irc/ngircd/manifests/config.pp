class ngircd::config {
  service { 'ngircd':
    enable  => true,
    ensure  => 'running',
    require => Package['ngircd'],
  }
}
