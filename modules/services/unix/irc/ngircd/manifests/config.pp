class ngircd::config {
  file { '/etc/ngircd/ngircd.conf':
    ensure  => present,
    source  => 'puppet:///modules/ngircd/ngircd.conf',
    require => Package['ngircd'],
    notify  => Service['ngircd'],
  }

  service { 'ngircd':
    enable   => true,
    ensure   => 'running',
    provider => systemd,
    require  => Package['ngircd'],
  }
}
