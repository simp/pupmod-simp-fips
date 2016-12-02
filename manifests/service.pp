# == Class fips::service
#
# This class is meant to be called from fips.
# It ensure the service is running.
#
class fips::service {
  assert_private()

  service { $::fips::service_name:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
  }
}
