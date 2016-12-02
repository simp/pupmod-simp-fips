# == Class fips::params
#
# This class is meant to be called from fips.
# It sets variables according to platform.
#
class fips::params {
  case $::osfamily {
    'RedHat': {
      $package_name = 'fips'
      $service_name = 'fips'
    }
    default: {
      fail("${::operatingsystem} not supported")
    }
  }
}
