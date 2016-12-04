# Default paramters for the fips class
#
class fips::params {
  case $facts['osfamily'] {
    'RedHat': {
      $enabled = true
    }
    default: {
      $enabled = false
    }
  }

  if $facts['cpuinfo'] and member($facts['cpuinfo']['processor0']['flags'], 'aes') {
    $aesni = true
  }
  else {
    $aesni = false
  }
}