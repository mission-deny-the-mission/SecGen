class hash_tools::install{
  # kali-rolling dropped the md5deep transitional package; hashdeep provides the md5deep/sha*deep commands
  if $operatingsystem == 'Kali' {
    package { ['hashdeep']:
      ensure => 'installed',
    }
  } else {
    package { ['md5deep']:
      ensure => 'installed',
    }
  }
  case $facts['os']['name'] {
    'Debian': {
      exec { 'hash_tools_apt_update':
        command   => '/usr/bin/apt-get update --fix-missing',
        path      => ['/bin', '/usr/bin'],
        tries     => 3,
        try_sleep => 10,
      }
      package { ['debsums']:
        ensure  => 'installed',
        require => Exec['hash_tools_apt_update'],
      }
    }
  }
}
