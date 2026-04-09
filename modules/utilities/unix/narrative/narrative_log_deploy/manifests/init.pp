class narrative_log_deploy::init {
  $secgen_parameters = secgen_functions::get_parameters($::base64_inputs_file)

  $log_content = $secgen_parameters['narrative_log_content']
  $log_files   = $secgen_parameters['log_file'] ? { undef => ['/var/log/narrative.log'], default => $secgen_parameters['log_file'] }

  if $log_content {
    $log_files.each |$target_log| {
      $content_combined = join($log_content, "\n")

      file { $target_log:
        ensure  => file,
        content => "${content_combined}\n",
        owner   => 'root',
        group   => 'adm',
        mode    => '0640',
      }
    }
  }
}
