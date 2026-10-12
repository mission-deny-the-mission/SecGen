class irc2::install {
  package { 'ngircd':
    ensure => 'installed',
  }
}
