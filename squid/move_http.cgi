#!/usr/local/bin/perl
# move_http.cgi
# Move a http_access directive up or down

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&lock_file($config{'squid_conf'});
my $conf = &get_config();
my ($pos, $move) = @ARGV;

my @https = &find_config("http_access", $conf);
my $newpos = $pos + $move;
my $oldv = $https[$pos]->{'values'};
$https[$pos]->{'values'} = $https[$newpos]->{'values'};
$https[$newpos]->{'values'} = $oldv;
&save_directive($conf, "http_access", \@https);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "http");
&redirect("edit_acl.cgi?mode=http");
