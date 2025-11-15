class ollama::config {
  require ollama::service

  # Get parameters from SecGen
  $secgen_parameters = secgen_functions::get_parameters($::base64_inputs_file)
  $model = $secgen_parameters['model'][0]

  # Pull the specified model if provided
  if $model {
    exec { "pull ollama model ${model}":
      command     => "ollama pull ${model}",
      path        => ['/usr/local/bin', '/usr/bin', '/bin'],
      environment => ['HOME=/root'],
      require     => Service['ollama'],
      timeout     => 1800,  # 30 minutes for large models
      unless      => "ollama list | grep -q '${model}'",
    }
  }
}
