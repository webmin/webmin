#!/usr/local/bin/perl
# move_always.cgi
# Move an always_direct directive up or down

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});

&lock_file($config{'squid_conf'});
my $conf = &get_config();
my ($pos, $move) = @ARGV;

my @always = &find_config("always_direct", $conf);
my $newpos = $pos + $move;
my $oldv = $always[$pos]->{'values'};
$always[$pos]->{'values'} = $always[$newpos]->{'values'};
$always[$newpos]->{'values'} = $oldv;
&save_directive($conf, "always_direct", \@always);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "always");
&redirect("edit_icp.cgi");
