class hackerbot3::config{
  require hackerbot3::install

  $secgen_parameters = secgen_functions::get_parameters($::base64_inputs_file)
  $port = $secgen_parameters['port'][0]

  $secgen_parameters['hackerbot_configs'].each |$counter, $config_pair| {
    $parsed_pair = parsejson($config_pair)

    notice("Creating bot config for hackerbot3")
    $xmlfilename = "bot_$counter.xml"

    file { "/opt/hackerbot3/config/$xmlfilename":
      ensure  => present,
      content => $parsed_pair['xml_config'],
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
    }

    # Lab sheet, served on $port (index.html for a single bot, as in Hackerbot 2)
    if $secgen_parameters['hackerbot_configs'].length == 1 {
      $htmlfilename = 'index.html'
    } else {
      $htmlfilename = "lab_part_${counter}.html"
    }
    if $parsed_pair['html_lab_sheet'] {
      file { "/var/www/labs2/${htmlfilename}":
        ensure  => present,
        content => $parsed_pair['html_lab_sheet'],
      }
    }

    # hb3.env for the service, from the first config: the LLM fallback (hb2_env, HB2_*) and the
    # decision router servers (hb3_env, HB3_*). Without HB3_DECISION_URL the router stays off and
    # the bot behaves like Hackerbot 2.
    if $counter == 0 {
      $hb2_env = $parsed_pair['hb2_env'] ? { undef => {}, default => $parsed_pair['hb2_env'] }
      $hb3_env = $parsed_pair['hb3_env'] ? { undef => {}, default => $parsed_pair['hb3_env'] }
      $env_lines = ($hb2_env + $hb3_env).map |$key, $value| { "${key}=${value}" }
      $env_content = $env_lines.join("\n")
      file { '/opt/hackerbot3/config/hb3.env':
        notify  => Service['hackerbot3'],
        ensure  => present,
        content => "${env_content}\n",
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
    notify  => Tidy['hb3 remove default site'],
  }

  ensure_resource('tidy', 'hb3 remove default site', { 'path' => '/etc/apache2/sites-enabled/000-default.conf' })

  # the Kali apache module does not enable apache2 on boot (same workaround as hackerbot2)
  exec { 'hackerbot3-apache2-systemd-reload':
    command => 'systemctl daemon-reload; systemctl enable apache2',
    path    => ['/usr/bin', '/bin', '/usr/sbin'],
  }
}
