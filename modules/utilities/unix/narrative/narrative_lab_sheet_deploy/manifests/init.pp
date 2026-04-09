class narrative_lab_sheet_deploy::init {
  $secgen_parameters = secgen_functions::get_parameters($::base64_inputs_file)
  $html_content = $secgen_parameters['narrative_lab_sheet_content'][0]

  file { '/var/www/labs':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/var/www/labs/index.html':
    ensure  => file,
    content => $html_content,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => File['/var/www/labs'],
  }

  class { '::apache':
    default_vhost => false,
  }

  apache::vhost { 'narrative.labs.com':
    port    => '80',
    docroot => '/var/www/labs',
    notify  => Tidy['narrative-remove-default-site'],
  }

  ensure_resource('tidy', 'narrative-remove-default-site', {'path' => '/etc/apache2/sites-enabled/000-default.conf'})

  exec { 'narrative-apache2-systemd-reload':
    command => 'systemctl daemon-reload; systemctl enable apache2',
    path    => ['/usr/bin', '/bin', '/usr/sbin'],
  }
}
