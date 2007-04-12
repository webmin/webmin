#!/usr/local/bin/perl
# move_never.cgi
# Move an never_direct directive up or down

require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&lock_file($config{'squid_conf'});
$conf = &get_config();
($pos, $move) = @ARGV;

@never = &find_config("never_direct", $conf);
$newpos = $pos + $move;
$oldv = $never[$pos]->{'values'};
$never[$pos]->{'values'} = $never[$newpos]->{'values'};
$never[$newpos]->{'values'} = $oldv;
&save_directive($conf, "never_direct", \@never);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "never");
&redirect("edit_icp.cgi");
