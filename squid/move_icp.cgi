#!/usr/local/bin/perl
# move_icp.cgi
# Move a icp_access directive up or down

require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&lock_file($config{'squid_conf'});
$conf = &get_config();
($pos, $move) = @ARGV;

@icps = &find_config("icp_access", $conf);
$newpos = $pos + $move;
$oldv = $icps[$pos]->{'values'};
$icps[$pos]->{'values'} = $icps[$newpos]->{'values'};
$icps[$newpos]->{'values'} = $oldv;
&save_directive($conf, "icp_access", \@icps);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "icp");
&redirect("edit_acl.cgi?mode=icp");
