# Manages the enabling and disabling of FIPS
#
class fips (
  Boolean $enabled = true,
  Boolean $aesni   = $::cpuinfo and member($::cpuinfo['processor0']['flags'],'aes')
) {

  if $enabled {
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
  else {
    kernel_parameter { 'fips':
      value  => '0',
      notify => Reboot_notify['fips']
      # bootmode => 'normal', # This doesn't work due to a bug in the Grub Augeas Provider
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
