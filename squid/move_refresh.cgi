#!/usr/local/bin/perl
# move_refresh.cgi
# Move a refresh_pattern directive up or down

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'refresh'} || &error($text{'header_ecannot'});
&lock_file($config{'squid_conf'});
my $conf = &get_config();
my ($pos, $move) = @ARGV;

my @refresh = &find_config("refresh_pattern", $conf);
my $newpos = $pos + $move;
my $oldv = $refresh[$pos]->{'values'};
$refresh[$pos]->{'values'} = $refresh[$newpos]->{'values'};
$refresh[$newpos]->{'values'} = $oldv;
&save_directive($conf, "refresh_pattern", \@refresh);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "refresh", $oldv->[0] eq "-i" ? $oldv->[1] : $oldv->[0]);
&redirect("list_refresh.cgi");
