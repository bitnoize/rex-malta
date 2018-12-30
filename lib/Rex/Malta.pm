package Rex::Malta;

use strict;
use warnings;

use Rex -feature => [ '1.4' ];

use constant DEBUG => $ENV{REX_DEBUG} ? 1 : 0;

our $VERSION = '0.03';

my $modules = get( 'modules' ) || [ ];
include map { "Rex::Malta::$_" } @$modules;

sub process {
  my ( $task, $param ) = @_;

  my %info = get_system_information;

  die "Only Debian systems supported yet, sorry\n"
    unless $info{operatingsystem} eq "Debian";

  map { "Rex::Malta::$_"->$task( %$param ) }
    grep { "Rex::Malta::$_"->config } @$modules;
}

task 'setup',   sub { process( setup  => @_ ) };
task 'clean',   sub { process( clean  => @_ ) };
task 'status',  sub { process( status => @_ ) };

task 'sysinfo', sub { dump_system_information };

task 'update',  sub {
  update_package_db;

  run 'remount_boot_rw',
    only_if => "mountpoint -q /boot",
    command => "mount -o remount,rw /boot";

  update_system
    dist_upgrade => TRUE,
    on_change => sub {
      Rex::Logger::info( "Update $_->{name} to $_->{version}" ) for @_;
    };

  run 'remount_boot_ro',
    only_if => "mountpoint -q /boot",
    command => "mount -o remount,ro /boot";

  my $packages = join "\n", map { $_->{name} } installed_packages;

  file "/root/packages", ensure => 'present',
    owner => 'root', group => 'root', mode => 644,
    content => $packages;

  file "/usr/local/sbin/reconfigure", ensure => 'present',
    owner => 'root', group => 'root', mode => 755,
    content => template( "\@reconfigure" );
};

sub header { "This file is auto-generated by (R)?ex" }

sub table {
  my ( $map, $sep, @data ) = @_;

  my $format = join " ", map { $_->{format} } @$map;
  my @header = map { $_->{field} } @$map;

  say sprintf $format, @header;

  for my $line ( @data ) {
    my @values = split $sep, $line;

    say sprintf $format,
      map { sprintf $_->{format}, $values[ $_->{id} ] } @$map;
  }
}

1;

__DATA__

@reconfigure
#!/bin/bash

#
# Reconfigure all installed packages by hand
#

[ -x "$( which dpkg-reconfigure )" ] || exit 100

PACKAGES_LIST=${PACKAGES_LIST:-/root/packages}

while read -r package; do
  [[ -z "$package" || "$package" =~ ^#.*$ ]] && continue

  echo "Reconfigure $package"

  dpkg-reconfigure -plow $package || true
done < "$PACKAGES_LIST"

exit 0
@end

