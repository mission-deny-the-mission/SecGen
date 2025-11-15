class ollama::service {
  require ollama::install

  # Ensure the systemd service is running
  service { 'ollama':
    ensure   => running,
    enable   => true,
    provider => systemd,
    require  => Exec['install ollama'],
  }
}
