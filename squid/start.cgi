#!/usr/local/bin/perl
# start.cgi
# Start squid

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'start'} || &error($text{'start_ecannot'});
use POSIX;
&ReadParse();
&error_setup($text{'start_ftsq'});

my $temp = &transname();
&clean_environment();
if ($config{'squid_start'}) {
	# Use a start script
	my $rv = &system_logged("$config{'squid_start'} >$temp 2>&1 </dev/null");
	sleep(5);
	my $errs = &read_file_contents($temp);
	unlink($temp);
	&reset_environment();
	if (!&is_squid_running()) {
		&system_logged(
			"$config{'squid_stop'} >/dev/null 2>&1 </dev/null");
		&error("<pre>".&html_escape($errs)."</pre>");
		}
	}
else {
	# Run the squid executable directly
	&system_logged("cd / ; $config{'squid_path'} -sY -f $config{'squid_conf'} >$temp 2>&1 </dev/null &");
	sleep(5);
	my $errs = &read_file_contents($temp);
	unlink($temp);
	&reset_environment();
	if ($errs) {
		&backquote_logged("$config{'squid_path'} -k shutdown -f $config{'squid_conf'} 2>&1 </dev/null");
		&error("<pre>".&html_escape($errs)."</pre>");
		}
	}
&webmin_log("start");
&redirect($in{'redir'});

