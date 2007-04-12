#!/usr/local/bin/perl
# move_always.cgi
# Move an always_direct directive up or down

require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&lock_file($config{'squid_conf'});
$conf = &get_config();
($pos, $move) = @ARGV;

@always = &find_config("always_direct", $conf);
$newpos = $pos + $move;
$oldv = $always[$pos]->{'values'};
$always[$pos]->{'values'} = $always[$newpos]->{'values'};
$always[$newpos]->{'values'} = $oldv;
&save_directive($conf, "always_direct", \@always);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "always");
&redirect("edit_icp.cgi");
