#!/usr/local/bin/perl
# move_http.cgi
# Move a http_access directive up or down

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

my @http_relies = &find_config("http_reply_access", $conf);
my $newpos = $pos + $move;
my $oldv = $http_relies[$pos]->{'values'};
$http_relies[$pos]->{'values'} = $http_relies[$newpos]->{'values'};
$http_relies[$newpos]->{'values'} = $oldv;
&save_directive($conf, "http_reply_access", \@http_relies);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "http");
&redirect("edit_acl.cgi?mode=reply");
