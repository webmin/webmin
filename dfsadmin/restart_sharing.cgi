#!/usr/local/bin/perl
# restart_sharing.cgi
# Call unshareall and shareall to stop and re-start file sharing

require './dfs-lib.pl';
$access{'view'} && &error($text{'ecannot'});
&error_setup($text{'restart_err'});
$err = &apply_configuration();
&error($err) if ($err);
&webmin_log("apply");
&redirect("");

