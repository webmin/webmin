#!/usr/local/bin/perl
# move_never.cgi
# Move an never_direct directive up or down

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

my @never = &find_config("never_direct", $conf);
my $newpos = $pos + $move;
my $oldv = $never[$pos]->{'values'};
$never[$pos]->{'values'} = $never[$newpos]->{'values'};
$never[$newpos]->{'values'} = $oldv;
&save_directive($conf, "never_direct", \@never);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "never");
&redirect("edit_icp.cgi");
