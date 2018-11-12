[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/fips.svg)](https://forge.puppetlabs.com/simp/fips)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/fips.svg)](https://forge.puppetlabs.com/simp/fips)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-fips.svg)](https://travis-ci.org/simp/pupmod-simp-fips)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with fips](#setup)
    * [What fips affects](#what-fips-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with fips](#beginning-with-fips)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
    * [Acceptance Tests - Beaker env variables](#acceptance-tests)

## Description

This module enables Federal Information Processing Standard(FIPS) mode. FIPS Publication 140-2, is a computer security
standard, developed by a U.S. Government and industry working group to validate the quality of cryptographic modules.
FIPS publications (including 140-2) can be found at the following URL: http://csrc.nist.gov/publications/PubsFIPS.html.
Enabling FIPS mode installs an integrity checking package and modifies ciphers available for applications to use.

This module manages the kernel parameters and packages required for enabling FIPS mode in CentOS and RHEL.

### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.


If you find any issues, they may be submitted to our [bug tracker](https://simp-project.atlassian.net/).

**FIXME:** Ensure the *This is a SIMP module* section is correct and complete, then remove this message!

This module is optimally designed for use within a larger SIMP ecosystem, but it can be used independently:

 * When included within the SIMP ecosystem, security compliance settings will be managed from the Puppet server.
 * If used independently, all SIMP-managed security subsystems are disabled by default and must be explicitly opted into by administrators.  Please review the `$client_nets`, `$enable_*` and `$use_*` parameters in `manifests/init.pp` for details.

## Setup

### What fips affects

-----------------------------------------
> **WARNING**
>
> FIPS mode disables md5 hashing at a library level. Enabling it may have unintended consequences.
-----------------------------------------

* Kernel parameters and Grub
* Dracut and initrd
* Packages:
  * nss
  * dracut-fips
  * fipscheck

### Beginning with fips

Include the `::fips` class. By default it will enable FIPS mode, but if you'd like to ensure that FIPS mode is disabled, call the class and set `fips::enabled: false` in hiera.

This section is where you describe how to customize, configure, and do the fancy stuff with your module here. It's especially helpful if you include usage examples and code samples for doing things with your module.

## Reference

Please refer to the inline documentation within each source file, or to the module's generated YARD documentation for reference material.

## Limitations

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux and compatible distributions, such as CentOS. Please see the [`metadata.json` file](./metadata.json) for the most up-to-date list of supported operating systems, Puppet versions, and module dependencies.

## Development

Please read our [Contribution Guide](http://simp-doc.readthedocs.io/en/stable/contributors_guide/index.html).


### Acceptance tests

This module includes [Beaker](https://github.com/puppetlabs/beaker) acceptance tests using the SIMP [Beaker Helpers](https://github.com/simp/rubygem-simp-beaker-helpers).  By default the tests use [Vagrant](https://www.vagrantup.com/) with [VirtualBox](https://www.virtualbox.org) as a back-end; Vagrant and VirtualBox must both be installed to run these tests without modification. To execute the tests run the following:

```shell
bundle install
bundle exec rake beaker:suites
```

**FIXME:** Ensure the *Acceptance tests* section is correct and complete, including any module-specific instructions, and remove this message!

Please refer to the [SIMP Beaker Helpers documentation](https://github.com/simp/rubygem-simp-beaker-helpers/blob/master/README.md) for more information.
