#!/usr/local/bin/perl
# start.cgi
# Save config and restart rpc.idmapd

require './idmapd-lib.pl';

&ReadParse();
&error_setup($text{'save_err', $config{'idmap_conf'}});

# Check directory
-d $in{'pipefsdir'} || &error(&text('error_dir', $in{'pipefsdir'}));

# Write the config file
&lock_file($config{'idmapd_conf'});
open(FILE, "> $config{'idmapd_conf'}");
print FILE "[General]\n";
print FILE "Pipefs-Directory = $in{'pipefsdir'}\n";
print FILE "Domain = $in{'domain'}\n";
print FILE "\n[Mapping]\n";
print FILE "Nobody-User = $in{'nobody_user'}\n";
print FILE "Nobody-Group = $in{'nobody_group'}\n";
close(FILE);
&unlock_file($config{'idmapd_conf'});

# Restart rpc.idmapd
local $temp = &transname();
local $rv = &system_logged("($config{'restart_command'}) </dev/null >$temp 2>&1");
local $out = `cat $temp`;
unlink($temp);
if ($rv) { &error("$out"); }

&redirect("");
