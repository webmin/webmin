#!/usr/local/bin/perl
# move_headeracc.cgi
# Move a header_access directive up or down

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'headeracc'} || &error($text{'header_ecannot'});
&lock_file($config{'squid_conf'});
my $conf = &get_config();
my ($pos, $move, $type) = @ARGV;

my @headeracc = &find_config($type, $conf);
my $newpos = $pos + $move;
my $oldv = $headeracc[$pos]->{'values'};
$headeracc[$pos]->{'values'} = $headeracc[$newpos]->{'values'};
$headeracc[$newpos]->{'values'} = $oldv;
&save_directive($conf, $type, \@headeracc);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "headeracc");
&redirect("list_headeracc.cgi");
