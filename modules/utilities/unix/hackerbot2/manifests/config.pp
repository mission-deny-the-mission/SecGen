class hackerbot2::config{
  require hackerbot2::install

  $secgen_parameters = secgen_functions::get_parameters($::base64_inputs_file)
  $port = $secgen_parameters['port'][0]

  $hackerbot_xml_configs = []
  $hackerbot_lab_sheets = []

  $secgen_parameters['hackerbot_configs'].each |$counter, $config_pair| {
    $parsed_pair = parsejson($config_pair)

    notice("Creating bot config for hackerbot2")
    $xmlfilename = "bot_$counter.xml"

    file { "/opt/hackerbot2/config/$xmlfilename":
      ensure => present,
      content => $parsed_pair['xml_config'],
      mode   => '0600',
      owner => 'root',
      group => 'root',
    }

    if $secgen_parameters['hackerbot_configs'].length == 1 {
      $htmlfilename = "index.html"
    } else {
      $htmlfilename = "lab_part_$counter.html"
    }

    file { "/var/www/labs2/$htmlfilename":
      ensure => present,
      content => $parsed_pair['html_lab_sheet'],
    }

    # Write hb2.env from the first config's hb2_env (LLM settings for the service)
    if $counter == 0 and $parsed_pair['hb2_env'] {
      $hb2_env_content = $parsed_pair['hb2_env'].map |$key, $value| {
        "${key}=${value}"
      }.join("\n")
      file { '/opt/hackerbot2/config/hb2.env':
        ensure  => present,
        content => "${hb2_env_content}\n",
        mode    => '0600',
        owner   => 'root',
        group   => 'root',
      }
    }
  }

  class { '::apache':
    default_vhost => false,
  }
  apache::vhost { 'vhost.labs2.com':
    port    => "$port",
    docroot => '/var/www/labs2',
    notify => Tidy['hb2 remove default site']
  }

  ensure_resource('tidy','hb2 remove default site', {'path'=>'/etc/apache2/sites-enabled/000-default.conf'})

  # not sure why the new kali apache module doesn't start on boot, this fixes it
  exec { 'hackerbot2-apache2-systemd-reload':
    command     => 'systemctl daemon-reload; systemctl enable apache2',
    path        => [ '/usr/bin', '/bin', '/usr/sbin' ],
  }
}
