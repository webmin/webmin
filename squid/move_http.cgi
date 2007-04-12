#!/usr/local/bin/perl
# move_http.cgi
# Move a http_access directive up or down

require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&lock_file($config{'squid_conf'});
$conf = &get_config();
($pos, $move) = @ARGV;

@https = &find_config("http_access", $conf);
$newpos = $pos + $move;
$oldv = $https[$pos]->{'values'};
$https[$pos]->{'values'} = $https[$newpos]->{'values'};
$https[$newpos]->{'values'} = $oldv;
&save_directive($conf, "http_access", \@https);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "http");
&redirect("edit_acl.cgi");
