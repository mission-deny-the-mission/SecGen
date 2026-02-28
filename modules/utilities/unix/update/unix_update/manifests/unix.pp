class unix_update::unix{
  case $operatingsystem {
    'Debian': {
      # Configure archive.debian.org for EOL releases (Stretch and older)
      # Replace all sources with archive.debian.org (main + security)
      file { '/etc/apt/sources.list':
        ensure  => file,
        content => "deb http://archive.debian.org/debian stretch main contrib non-free\ndeb http://archive.debian.org/debian-security stretch/updates main contrib non-free\n",
        before  => Exec['update'],
      }
      # Remove any conflicting source files
      exec { 'clean-sources':
        command => "/bin/rm -f /etc/apt/sources.list.d/*.list 2>/dev/null || true",
        before  => Exec['update'],
      }
      # Allow apt to work with repositories that have expired signatures
      file { '/etc/apt/apt.conf.d/99archive':
        ensure  => file,
        content => "Acquire::Check-Valid-Until \"false\";\nAcquire::Check-Date \"false\";\nAcquire::AllowInsecureRepositories \"true\";\n",
        before  => Exec['update'],
      }
      exec { 'update':
        command => "/usr/bin/apt-get update --fix-missing",
        tries => 5,
        try_sleep => 30,
      }
    }
    'Kali': {
      exec { 'update':
        command => "/usr/bin/apt-get update --fix-missing",
        tries => 5,
        try_sleep => 30,
      }
    }
    'Ubuntu': {
      exec { 'update':
        command => "/usr/bin/apt-get update --fix-missing",
        tries => 5,
        try_sleep => 30,
      }
    }
    'RedHat': {
      exec { 'update':
        command => "yum update",
        tries => 5,
        try_sleep => 30,
      }
    }
    'CentOS': {
      exec { 'update':
        command => "su -c 'yum update'",
        tries => 5,
        try_sleep => 30,
      }
    }
    'Solaris': {
      exec { 'update':
        command => "pkg update",
        tries => 5,
        try_sleep => 30,
      }
    }
  }
}
