# == Class fips::install
#
# This class is called from fips for install.
#
class fips::install {
  assert_private()

  package { $::fips::package_name:
    ensure => present,
  }
}
