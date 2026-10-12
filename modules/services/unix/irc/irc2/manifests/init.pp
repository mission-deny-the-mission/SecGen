class irc2 {
  include irc2::install
  include irc2::config
  include irc2::service

  Class['irc2::install']
  -> Class['irc2::config']
  -> Class['irc2::service']
}
