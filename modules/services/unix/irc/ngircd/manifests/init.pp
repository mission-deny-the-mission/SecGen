class ngircd {
  include ngircd::install
  include ngircd::config

  Class['ngircd::install']
  -> Class['ngircd::config']
}
