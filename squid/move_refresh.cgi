#!/usr/local/bin/perl
# move_refresh.cgi
# Move a refresh_pattern directive up or down

require './squid-lib.pl';
$access{'refresh'} || &error($text{'header_ecannot'});
&lock_file($config{'squid_conf'});
$conf = &get_config();
($pos, $move) = @ARGV;

@refresh = &find_config("refresh_pattern", $conf);
$newpos = $pos + $move;
$oldv = $refresh[$pos]->{'values'};
$refresh[$pos]->{'values'} = $refresh[$newpos]->{'values'};
$refresh[$newpos]->{'values'} = $oldv;
&save_directive($conf, "refresh_pattern", \@refresh);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "refresh", $oldv->[0] eq "-i" ? $oldv->[1] : $oldv->[0]);
&redirect("list_refresh.cgi");
