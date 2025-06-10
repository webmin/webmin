#!/usr/local/bin/perl
# save_misc.cgi
# Save global miscellaneous options
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'misc_ecannot'});
&error_setup($text{'controls_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
my $conf = &get_config();
my $controls = &find("controls", $conf);

if ($in{'inet_def'} && $in{'unix_def'}) {
  if (defined($controls)) {
    &save_directive(&get_config_parent(), 'controls', [ ], 0);
  }
} else {
  if (!defined($controls)) {
    $controls={ 'name' => 'controls', 'type' => 1 };
    &save_directive(&get_config_parent(), 'controls', [ $controls ], 0);
  }
  if (!$in{'inet_def'}) {
    my $addr=$in{'inetaddr'};
    &check_ipaddress($addr) || &error(&text('controls_eip', $addr));

    my $port=$in{'inetport'};
    $port =~ /^\d+$/ || &error($text{'controls_eport'});
    my @allows=();
    foreach my $allow (split(/\s+/, $in{'inetallow'})) {
      # Need to check acl is OK!
      push(@allows, { 'name' => $allow });
    }

    my $inetdir = { 'name' => 'inet', 'type' => 1,
		    'values' => [ $addr,
				  'port', $port,
				  'allow' ],
		    'members' => \@allows };

    &save_directive($controls, "inet", [ $inetdir ], 1);
  } else {
    &save_directive($controls, "inet", [ ], 1);
  }

  if (!$in{'unix_def'}) {
    my $file=$in{'unixfile'};
    my $perms=$in{'unixperms'};
    my $owner=$in{'unixowner'};
    my $group=$in{'unixgroup'};
    $file =~ /^\S+$/ || &error($text{'controls_efile'});
    $perms =~ /^\d+$/ || &error($text{'controls_eperms'});
    $owner =~ /^\d+$/ || &error($text{'controls_eowner'});
    $group =~ /^\d+$/ || &error($text{'controls_egroup'});

    my $unixdir = { 'name' => 'unix', 'type' => 0,
		    'values' => [ "\"$file\"",
				  'perm', $perms,
				  'owner', $owner,
				  'group', $group ] };

    &save_directive($controls, "unix", [ $unixdir ], 1);
  } else {
    &save_directive($controls, "unix", [ ], 1);
  }
}

&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("controls", undef, undef, \%in);
&redirect("");

