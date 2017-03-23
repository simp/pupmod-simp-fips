# Manages disabling of FIPS
#
#  This module will set the boot parameter fips to 0 so the system 
#  is not booted with fips
class fips::disable {

  kernel_parameter { 'fips':
    value  => '0',
    notify => Reboot_notify['fips']
    # bootmode => 'normal', # This doesn't work due to a bug in the Grub Augeas Provider
  }

}
