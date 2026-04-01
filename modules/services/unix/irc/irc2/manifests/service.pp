class irc2::service {
  service { 'ircd-irc2':
    enable  => true,
    ensure  => 'running',
    require => Package['ircd-irc2'],
  }
}
