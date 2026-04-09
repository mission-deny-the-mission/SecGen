class narrative_document_deploy::init {
  $secgen_parameters = secgen_functions::get_parameters($::base64_inputs_file)

  $doc_content = $secgen_parameters['narrative_document_content']
  $doc_paths   = $secgen_parameters['document_path'] ? { undef => ['/opt/documents'], default => $secgen_parameters['document_path'] }
  $doc_names   = $secgen_parameters['document_name']

  if $doc_content {
    $doc_path_real = $doc_paths[0]

    # Ensure document directory exists
    file { $doc_path_real:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    $doc_content.each |$index| {
      $raw_doc = $doc_content[$index]
      $doc = parsejson($raw_doc)

      $filename = $doc['filename'] ? {
        undef => $doc_names ? {
          undef => "document_${index}.txt",
          default => $doc_names[$index] ? { undef => "document_${index}.txt", default => $doc_names[$index] }
        },
        default => $doc['filename']
      }

      $file_path = "${doc_path_real}/${filename}"

      file { $file_path:
        ensure  => file,
        content => $doc['content'],
        owner   => $doc['owner'] ? { undef => 'root', default => $doc['owner'] },
        group   => $doc['group'] ? { undef => 'root', default => $doc['group'] },
        mode    => $doc['mode'] ? { undef => '0644', default => $doc['mode'] },
        require => File[$doc_path_real],
      }
    }
  }
}
