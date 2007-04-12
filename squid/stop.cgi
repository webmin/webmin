#!/usr/local/bin/perl
# stop.cgi
# Stop the running squid process

require './squid-lib.pl';
$access{'start'} || &error($text{'stop_ecannot'});
&ReadParse();
$whatfailed = $text{'stop_ftsq'};
if ($config{'squid_stop'}) {
	# Use a stop script
	$out = &backquote_logged("$config{'squid_stop'} 2>&1");
	if ($out && $out =~ /\d+\/\d+\/\d+/) {
		&error("<pre>$out</pre>");
		}
	}
else {
	# Run the squid executable directly
	$out = &backquote_logged("$config{'squid_path'} -f $config{'squid_conf'} -k shutdown 2>&1");
	if ($out) { &error("<pre>$out</pre>"); }
	}
for($i=0; $i<40; $i++) {
	if (!kill(0, $in{'pid'})) { last; }
	sleep(1);
	}
&webmin_log("stop");
&redirect($in{'redir'});

