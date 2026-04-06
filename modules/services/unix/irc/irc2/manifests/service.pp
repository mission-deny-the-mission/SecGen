class irc2::service {
  service { 'ngircd':
    enable  => true,
    ensure  => 'running',
    require => Package['ngircd'],
  }
}
