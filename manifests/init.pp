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

      $fips_kernel_value = $enabled ? {
        true    => '1',
        default => '0'
      }

      $fips_package_status = $enabled ? {
        true    => 'latest',
        default => 'absent'
      }

      kernel_parameter {
        'fips':
          value  => $fips_kernel_value,
          notify => Reboot_notify['fips'];
          # bootmode => 'normal', # This doesn't work due to a bug in the Grub Augeas Provider
        'boot':
          value  => "UUID=${::boot_dir_uuid}",
          notify => Reboot_notify['fips'];
          # bootmode => 'normal', # This doesn't work due to a bug in the Grub Augeas Provider
      }

      package {
        'dracut-fips':
          ensure => $fips_package_status,
          notify => Exec['dracut_rebuild'];
        'fipscheck':
          ensure => $fips_package_status
      }

      if $aesni {
        package { 'dracut-fips-aesni':
          ensure => $fips_package_status,
          notify => Exec['dracut_rebuild']
        }
        # There were failures if the packages are not removed/installed in the correct
        # order
        if $enabled {
          Package['dracut-fips'] -> Package['dracut-fips-aesni']
        } else {
          Package['dracut-fips-aesni'] -> Package['dracut-fips']
        }
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
