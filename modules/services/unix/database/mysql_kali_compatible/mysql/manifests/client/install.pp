# @summary
#   Private class for MySQL client install.
#
# @api private
#
class mysql::client::install {
  notice("Doing an install of mysql client")

  # if $mysql::client::package_manage {
  #   package { 'mysql_client':
  #     ensure          => $mysql::client::package_ensure,
  #     install_options => $mysql::client::install_options,
  #     name            => $mysql::client::package_name,
  #     provider        => $mysql::client::package_provider,
  #     source          => $mysql::client::package_source,
  #   }
  # }
}
