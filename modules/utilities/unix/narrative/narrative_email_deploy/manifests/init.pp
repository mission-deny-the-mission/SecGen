class narrative_email_deploy::init {
  $secgen_parameters = secgen_functions::get_parameters($::base64_inputs_file)

  $email_content = $secgen_parameters['narrative_email_content']
  $mail_dir      = $secgen_parameters['mail_directory'] ? { undef => ['/var/mail'], default => $secgen_parameters['mail_directory'] }
  $mail_user     = $secgen_parameters['mail_user'] ? { undef => ['root'], default => $secgen_parameters['mail_user'] }

  if $email_content {
    $mail_dir_real = $mail_dir[0]
    $mail_user_real = $mail_user[0]

    $email_content.each |$raw_email| {
      $email = parsejson($raw_email)
      $recipient = $email['recipient'] ? { undef => 'root', default => $email['recipient'] }
      $file_path = "${mail_dir_real}/${recipient}"

      # Ensure mail directory exists
      file { $mail_dir_real:
        ensure => directory,
        owner  => 'root',
        group  => 'mail',
        mode   => '3775',
        before => File[$file_path],
      }

      # Create or append to the mail spool file
      file { $file_path:
        ensure  => file,
        content => $email['content'],
        owner   => $mail_user_real,
        group   => 'mail',
        mode    => '0660',
      }
    }
  }
}
