# == Class fips::config::firewall
#
# This class is meant to be called from fips.
# It ensures that firewall rules are defined.
#
class fips::config::firewall {
  assert_private()

  # FIXME: ensure yoour module's firewall settings are defined here.
  iptables::add_tcp_stateful_listen { 'allow_fips_tcp_connections':
    client_nets => $::fips::client_nets,
    dports      => $::fips::tcp_listen_port,
  }

}
