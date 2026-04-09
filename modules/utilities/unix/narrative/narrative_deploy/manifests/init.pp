class narrative_deploy::init {
  $secgen_parameters = secgen_functions::get_parameters($::base64_inputs_file)

  $narrative_files = $secgen_parameters['narrative_files']
  if $narrative_files {
    $narrative_files.each |$raw_file_spec| {
      $file_spec = parsejson($raw_file_spec)

      $file_path    = $file_spec['path']
      $file_content = $file_spec['content']
      $file_owner   = $file_spec['owner'] ? { undef => 'root', default => $file_spec['owner'] }
      $file_group   = $file_spec['group'] ? { undef => 'root', default => $file_spec['group'] }
      $file_mode    = $file_spec['mode'] ? { undef => '0644', default => $file_spec['mode'] }

      # Ensure the parent directory exists
      $parent_dir = dirname($file_path)
      file { $parent_dir:
        ensure => directory,
        owner  => $file_owner,
        group  => $file_group,
        mode   => '0755',
        before => File[$file_path],
      }

      # Create the narrative content file
      file { $file_path:
        ensure  => file,
        content => $file_content,
        owner   => $file_owner,
        group   => $file_group,
        mode    => $file_mode,
      }
    }
  }
}
