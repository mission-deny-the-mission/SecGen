class ollama::install {
  # Ensure curl is installed for downloading Ollama
  ensure_packages(['curl'])

  # Download and install Ollama
  exec { 'install ollama':
    command => 'curl -fsSL https://ollama.ai/install.sh | sh',
    path    => ['/usr/bin', '/bin', '/usr/sbin', '/sbin'],
    creates => '/usr/local/bin/ollama',
    require => Package['curl'],
    timeout => 600,
  }

  # Ensure the ollama user exists (created by the install script)
  # This is just a safety check
  user { 'ollama':
    ensure  => present,
    system  => true,
    require => Exec['install ollama'],
  }

  # Create directory for Ollama models
  file { '/usr/share/ollama':
    ensure  => directory,
    owner   => 'ollama',
    group   => 'ollama',
    mode    => '0755',
    require => User['ollama'],
  }
}
