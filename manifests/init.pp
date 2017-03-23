# Manages the enabling and disabling of FIPS
#
# Warning:  FIPS mode uses a smaller crytpo set and shorter keys
#           Changing from  non-fips mode to fips will probably
#           require all keys and certs used by server, like the
#           puppet server, unusable.
class fips (
  Boolean $enabled = simplib::lookup('simp_options::fips', { 'default_value' => true }),
  Boolean $aesni   = $::fips::params::aesni
) inherits fips::params {

  case $facts['os']['family'] {
    'RedHat': {
      if $enabled {
        include 'fips::enable'
      }
      else {
        include 'fips::disable'
      }

      reboot_notify { 'fips': }

      # If the NSS and dracut packages don't stay reasonably in sync, your system
      # may not reboot.
      package { 'nss': ensure => 'latest' }

      exec { 'dracut_rebuild':
        command     => '/sbin/dracut -f',
        subscribe   => Package['nss'],
        refreshonly => true
      }
    }
    default : {
      fail('Only the RedHat family is supported by the simp fips module at this time.')
    }
  }
}
