#!/usr/local/bin/perl
# stop.cgi
# Stop the running squid process

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'start'} || &error($text{'stop_ecannot'});
&ReadParse();
&error_setup($text{'stop_ftsq'});

my $pid = &is_squid_running();
if ($config{'squid_stop'}) {
	# Use a stop script
	my $out = &backquote_logged("$config{'squid_stop'} 2>&1");
	if ($out && $out =~ /\d+\/\d+\/\d+/) {
		&error("<pre>".&html_escape($out)."</pre>");
		}
	}
else {
	# Run the squid executable directly
	my $out = &backquote_logged("$config{'squid_path'} -f $config{'squid_conf'} -k shutdown 2>&1");
	if ($out) {
		&error("<pre>".&html_escape($out)."</pre>");
		}
	}
for(my $i=0; $i<40; $i++) {
	if (!kill(0, $pid)) { last; }
	sleep(1);
	}
&webmin_log("stop");
&redirect($in{'redir'});

