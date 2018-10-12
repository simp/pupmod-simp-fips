# This module manages the enabling and disabling of FIPS on a system
# It will set the kernel boot parametes and install/remove the dracut packages
# and rebuild initramfs images.
#
# Changing the FIPS status of a system changes the cryptographic modules used.
# This can affect existing keys and certificates and make them unusable.  Make
# sure these effects are understood before changing the status.
#
# @param enabled
#   If FIPS should be enabled or disabled on the system.
#
#   * NOTE: Given the dangerous nature of FIPS unexpectedly being activated on
#     a system, this module mirrors the existing status of FIPS on the system
#     to which it is applied.
#
# @param aesni
#   NOTE: This parameter is controlled by params.pp
#   This parameter indicates whether the system uses the
#   Advanced Encryption Standard New Instructions set.
#
# @param dracut_ensure The ensure status of the dracut-fips and
#   dracut-fips-aesni packages
#
# @param fipscheck_ensure The ensure status of the fipscheck package
#
# @param nss_ensure The ensure status of the nss package
#
class fips (
  Boolean $enabled = simplib::lookup('simp_options::fips', { 'default_value' => $facts['fips_enabled']}),
  Boolean $aesni   = $::fips::params::aesni,
  String  $dracut_ensure    = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  String  $fipscheck_ensure = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  String  $nss_ensure       = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' })
) inherits fips::params {

  simplib::assert_metadata($module_name)

  case $facts['os']['family'] {
    'RedHat': {
      $fips_kernel_value = $enabled ? {
        true    => '1',
        default => '0'
      }

      # The dracut packages need to removed/added and the image rebuilt
      # depending on fips status or the system won't boot properly.
      $fips_package_status = $enabled ? {
        true    => $dracut_ensure,
        default => 'absent'
      }

      kernel_parameter { 'fips':
        value  => $fips_kernel_value,
        notify => Reboot_notify['fips']
        # bootmode => 'normal', # This doesn't work due to a bug in the Grub Augeas Provider
      }

      # This should only be present if /boot is on a separate partition
      if $facts['boot_dir_uuid'] and $facts['root_dir_uuid'] {
        if ($facts['boot_dir_uuid'] == $facts['root_dir_uuid']) {
          kernel_parameter { 'boot':
            ensure => absent,
            notify => Reboot_notify['fips'];
            # bootmode => 'normal', # This doesn't work due to a bug in the Grub Augeas Provider
          }
        }
        else {
          kernel_parameter { 'boot':
            value  => "UUID=${facts['boot_dir_uuid']}",
            notify => Reboot_notify['fips'];
            # bootmode => 'normal', # This doesn't work due to a bug in the Grub Augeas Provider
          }
        }
      }

      package {
        'dracut-fips':
          ensure => $fips_package_status,
          notify => Exec['dracut_rebuild'];

        'fipscheck':
          ensure => $fipscheck_ensure
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
        }
        else {
          Package['dracut-fips-aesni'] -> Package['dracut-fips']
        }
      }

      reboot_notify { 'fips':
        reason => 'The status of the fips kernel parameter has changed'
      }

      # If the NSS and dracut packages don't stay reasonably in sync, your system
      # may not reboot.
      package { 'nss':
        ensure => $nss_ensure
      }

      exec { 'dracut_rebuild':
        command     => '/sbin/dracut -f',
        subscribe   => Package['nss'],
        refreshonly => true,
        notify      => Reboot_notify['fips'];
      }
    }
  }
}
