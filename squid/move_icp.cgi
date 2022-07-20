#!/usr/local/bin/perl
# move_icp.cgi
# Move a icp_access directive up or down

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&lock_file($config{'squid_conf'});
my $conf = &get_config();
my ($pos, $move) = @ARGV;

my @icps = &find_config("icp_access", $conf);
my $newpos = $pos + $move;
my $oldv = $icps[$pos]->{'values'};
$icps[$pos]->{'values'} = $icps[$newpos]->{'values'};
$icps[$newpos]->{'values'} = $oldv;
&save_directive($conf, "icp_access", \@icps);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "icp");
&redirect("edit_acl.cgi?mode=icp");
