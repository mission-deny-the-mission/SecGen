# ZeroClaw Puppet Module - Main Class
# Deploys ZeroClaw AI agent for SecGen Hackerbot scenarios
#
# This module installs and configures ZeroClaw alongside the existing
# Ruby Hackerbot for parallel testing and gradual migration.
#
# Usage:
#   include zeroclaw
#
# Or with parameters:
#   class { '::zeroclaw':
#     irc_server_ip         => 'localhost',
#     irc_port              => 6668,
#     hackerbot_configs     => [...],
#     secgen_datastore_path => '/var/lib/secgen/datastore.json',
#   }

class zeroclaw (
  String $irc_server_ip = 'localhost',
  Integer $irc_port = 6668,
  Array[String] $hackerbot_configs = [],
  String $secgen_datastore_path = '/var/lib/secgen/datastore.json',
  String $ollama_host = 'localhost',
  Integer $ollama_port = 11434,
  String $ollama_model = 'gemma3:1b',
) {
  include zeroclaw::install
  include zeroclaw::config
  include zeroclaw::service

  # Ensure dependencies are met
  require zeroclaw::install
}
