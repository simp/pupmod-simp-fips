# Manages the enabling FIPS
#
# This module will install fips dracut modules and set the fips
# boot parameter to 1 so the system will boot into fips mode
#
class fips::enable (
  Boolean $aesni   = $::fips::params::aesni
) {

  kernel_parameter {
    'fips':
      value  => '1',
      notify => Reboot_notify['fips'];
      # bootmode => 'normal', # This doesn't work due to a bug in the Grub Augeas Provider
    'boot':
      value  => "UUID=${::boot_dir_uuid}",
      notify => Reboot_notify['fips'];
      # bootmode => 'normal', # This doesn't work due to a bug in the Grub Augeas Provider
  }

  package {
    'dracut-fips':
      ensure => 'latest',
      notify => Exec['dracut_rebuild'];
    'fipscheck':
      ensure => 'latest'
  }

  if $aesni {
    package { 'dracut-fips-aesni':
      ensure => 'latest',
      notify => Exec['dracut_rebuild']
    }
  }

}

