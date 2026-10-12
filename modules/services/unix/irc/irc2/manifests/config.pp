class irc2::config {
  file { '/etc/ngircd/ngircd.conf':
    ensure  => present,
    content => "[Global]\n    Name = irc.example.net\n    Info = SecGen IRC Server\n    MotdFile = /etc/ngircd/ngircd.motd\n    Listen = 0.0.0.0\n    Ports = 6667\n    MaxNickLength = 30\n\n[Options]\n    DNS = no\n    Ident = no\n    PAM = no\n\n[Channel]\n    Name = #Hackerbot\n    Topic = Hackerbot chat channel\n",
    require => Package['ngircd'],
    notify  => Service['ngircd'],
  }

  file { '/etc/ngircd/ngircd.motd':
    ensure  => present,
    content => "Welcome to the SecGen IRC server!\n",
    require => Package['ngircd'],
  }
}
