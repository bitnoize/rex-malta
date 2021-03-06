package Rex::Helm::Firewall;

use strict;
use warnings;

use Rex -feature => [ '1.4' ];

sub config {
  my ( $force ) = @_;

  my $config = param_lookup 'firewall', { };
  return unless $config->{active} or $force;

  my $firewall = {
    active      => $config->{active}  // FALSE,
    type        => $config->{type}    || 'simple',
    inline      => $config->{inline}  || { },
  };

  inspect $firewall if Rex::Helm::DEBUG;

  set 'firewall' => $firewall;
};

task 'setup' => sub {
  return unless my $firewall = config;

  case $firewall->{type}, {
    'simple' => sub {
      pkg [ qw/iptables-persistent/ ], ensure => 'present';

      file "/etc/default/netfilter-persistent", ensure => 'present',
        owner => 'root', group => 'root', mode => 644,
        content => template( "files/default.netfilter-persistent" );

      file "/etc/iptables", ensure => 'directory',
        owner => 'root', group => 'root', mode => 2750;

      file "/etc/iptables/rules.v4", ensure => 'present',
        owner => 'root', group => 'root', mode => 640,
        content => template( "files/iptables.rules.v4" );

      file "/etc/iptables/rules.v6", ensure => 'present',
        owner => 'root', group => 'root', mode => 640,
        content => template( "files/iptables.rules.v6" );

      service 'netfilter-persistent', ensure => 'started';
      service 'netfilter-persistent' => 'restart';
    },

    'ferm' => sub {
      pkg [ qw/ferm/ ], ensure => 'present';

      file "/etc/default/ferm", ensure => 'present',
        owner => 'root', group => 'root', mode => 644,
        content => template( "files/default.ferm" );

      file "/etc/ferm", ensure => 'directory',
        owner => 'root', group => 'adm', mode => 2750;

      file "/etc/ferm/ferm.conf", ensure => 'present',
        owner => 'root', group => 'adm', mode => 640,
        content => template( "files/ferm.conf" );

      service 'ferm', ensure => 'started';
      service 'ferm' => 'restart';
    },

    default => sub { die "Firewall has unknown type\n" }
  };
};

task 'clean' => sub {
  return unless my $firewall = config;

};

task 'remove' => sub {
  my $firewall = config -force;

  pkg [ qw/iptables-persistent ferm/ ], ensure => 'absent';

  file [ qw{
    /etc/default/netfilter-persistent
    /etc/iptables
    /etc/default/ferm
    /etc/ferm
  } ], ensure => 'absent';
};

task 'status' => sub {
  my $firewall = config -force;

};

1;
