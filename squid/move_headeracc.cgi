#!/usr/local/bin/perl
# move_headeracc.cgi
# Move a header_access directive up or down

require './squid-lib.pl';
$access{'headeracc'} || &error($text{'header_ecannot'});
&lock_file($config{'squid_conf'});
$conf = &get_config();
($pos, $move) = @ARGV;

@headeracc = &find_config("header_access", $conf);
$newpos = $pos + $move;
$oldv = $headeracc[$pos]->{'values'};
$headeracc[$pos]->{'values'} = $headeracc[$newpos]->{'values'};
$headeracc[$newpos]->{'values'} = $oldv;
&save_directive($conf, "header_access", \@headeracc);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "headeracc");
&redirect("list_headeracc.cgi");
