#!/usr/local/bin/perl
# move_http.cgi
# Move a http_access directive up or down

require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&lock_file($config{'squid_conf'});
$conf = &get_config();
($pos, $move) = @ARGV;

@http_relies = &find_config("http_reply_access", $conf);
$newpos = $pos + $move;
$oldv = $http_relies[$pos]->{'values'};
$http_relies[$pos]->{'values'} = $http_relies[$newpos]->{'values'};
$http_relies[$newpos]->{'values'} = $oldv;
&save_directive($conf, "http_reply_access", \@http_relies);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "http");
&redirect("edit_acl.cgi?mode=reply");
