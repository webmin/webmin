#!/usr/local/bin/perl
# monitor_action.cgi
# Run a monitor service action and return to the referring page

require './init-lib.pl';
&ReadParse();
&error_setup($text{'monitor_err'});
# Recheck permission when the action is submitted
$access{'bootup'} || &error($text{'ss_ecannot'});

# Accept only supported actions on services known to the init module
my %funcs = ( 'start' => \&start_action,
	      'stop' => \&stop_action,
	      'restart' => \&restart_action );
my $func = $funcs{$in{'action'}};
$func && &indexof($in{'name'}, &list_action_names()) >= 0 ||
	&error($text{'monitor_ename'});

if ($in{'name'} =~ /^webmin(\.service)?$/) {
	# Only allow Webmin to restart itself through its own restart helper
	$in{'action'} eq 'restart' ||
		&error(&text('mass_enoallow', &html_escape($in{'name'})));
	$SIG{'TERM'} = 'ignore';
	&restart_miniserv();
	}
else {
	# Run the service action and show escaped output on failure
	my ($ok, $out) = &$func($in{'name'});
	$ok || &error("<pre>".&html_escape($out)."</pre>");
	}
# Log success and return to the referring page or module index
&webmin_log($in{'action'}, 'action', $in{'name'});
&redirect(&get_referer_relative() || "");
