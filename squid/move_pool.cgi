#!/usr/local/bin/perl
# move_delay.cgi
# Move a delay_access directive up or down

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'delay'} || &error($text{'delay_ecannot'});
&lock_file($config{'squid_conf'});
my $conf = &get_config();
my ($pos, $move, $idx) = @ARGV;

my @delays = &find_config("delay_access", $conf);
my @access = grep { $_->{'values'}->[0] == $idx } @delays;
my $newpos = $pos + $move;
my $oldv = $access[$pos]->{'values'};
$access[$pos]->{'values'} = $access[$newpos]->{'values'};
$access[$newpos]->{'values'} = $oldv;
&save_directive($conf, "delay_access", \@delays);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "delay", $idx);
&redirect("edit_pool.cgi?idx=$idx");
