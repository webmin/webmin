#!/usr/local/bin/perl
# move_delay.cgi
# Move a delay_access directive up or down

require './squid-lib.pl';
$access{'delay'} || &error($text{'delay_ecannot'});
&lock_file($config{'squid_conf'});
$conf = &get_config();
($pos, $move, $idx) = @ARGV;

@delays = &find_config("delay_access", $conf);
@access = grep { $_->{'values'}->[0] == $idx } @delays;
$newpos = $pos + $move;
$oldv = $access[$pos]->{'values'};
$access[$pos]->{'values'} = $access[$newpos]->{'values'};
$access[$newpos]->{'values'} = $oldv;
&save_directive($conf, "delay_access", \@delays);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("move", "delay", $idx);
&redirect("edit_pool.cgi?idx=$idx");
