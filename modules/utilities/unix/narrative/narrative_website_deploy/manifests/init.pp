class narrative_website_deploy::init {
  $secgen_parameters = secgen_functions::get_parameters($::base64_inputs_file)

  $web_content = $secgen_parameters['narrative_website_content']
  $web_roots   = $secgen_parameters['web_root'] ? { undef => ['/var/www/html'], default => $secgen_parameters['web_root'] }

  if $web_content {
    $web_root_real = $web_roots[0]

    # Ensure web root exists
    file { $web_root_real:
      ensure => directory,
      owner  => 'www-data',
      group  => 'www-data',
      mode   => '0755',
    }

    $web_content.each |$raw_page| {
      $page = parsejson($raw_page)
      $filename = $page['filename'] ? { undef => 'index.html', default => $page['filename'] }
      $file_path = "${web_root_real}/${filename}"

      file { $file_path:
        ensure  => file,
        content => $page['content'],
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0644',
        require => File[$web_root_real],
      }
    }
  }
}
