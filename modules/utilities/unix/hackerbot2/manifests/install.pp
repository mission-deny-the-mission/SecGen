class hackerbot2::install {
  file { '/opt/hackerbot2':
    ensure  => directory,
    recurse => true,
    source  => 'puppet:///modules/hackerbot2/opt_hackerbot2',
    mode    => '0700',
    owner   => 'root',
    group   => 'root',
  }

  file { '/var/www/labs2':
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  # System dependencies required for nokogiri and other gems
  $system_packages = [
    'zlibc',
    'zlib1g',
    'zlib1g-dev',
    'sshpass',
    'build-essential',
    'patch',
    'ruby-dev',
    'liblzma-dev',
    'libxml2-dev',
    'libxslt1-dev',
    'pkg-config'
  ]
  ensure_packages($system_packages)

  # Basic gems without nokogiri
  $gem_packages = ['nori', 'json', 'httparty', 'thwait', 'kramdown', 'ircinch']
  ensure_packages($gem_packages, {
    'provider' => 'gem',
    'require'  => Package['build-essential'],
  })

  # Remove problematic nokogiri installation first (tolerant of "not installed")
  exec { 'remove nokogiri for hackerbot2':
    command => 'gem uninstall nokogiri -a -x --force 2>/dev/null; /bin/true',
    path    => [ '/usr/bin', '/bin', '/usr/sbin' ],
    onlyif  => 'gem list nokogiri -i',
  }

  # Install nokogiri with system libraries
  exec { 'install nokogiri for hackerbot2':
    command => 'gem install nokogiri -v 1.15.5 --no-document',
    path    => [ '/usr/bin', '/bin', '/usr/sbin' ],
    require => [
      Package[$system_packages],
      Exec['remove nokogiri for hackerbot2']
    ],
    unless  => 'gem list nokogiri -i',
  }
}
