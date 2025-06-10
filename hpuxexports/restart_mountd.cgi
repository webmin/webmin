#!/usr/local/bin/perl
# restart_mountd.cgi
# Do whatever is needed to apply changes to the exports file

require './exports-lib.pl';
$whatfailed = "Failed to apply changes";
&system_logged("$config{'portmap_command'} >/dev/null 2>&1 </dev/null")
	if ($config{'portmap_command'});
$temp = &transname();
$rv = &system_logged("($config{'restart_command'}) </dev/null >$temp 2>&1");
$out = `cat $temp`;
unlink($temp);
#if ($rv) { <-- This seems to be a bug
if ($out) {
	# something went wrong.. display an error
	&error($out);
	}
&webmin_log('apply');
&redirect("");
