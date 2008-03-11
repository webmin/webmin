#!/usr/local/bin/perl
# start.cgi
# Start the fetchmail daemon

require './fetchmail-lib.pl';
&ReadParse();
&error_setup($text{'start_err'});
$config{'config_file'} || $< || &error($text{'start_ecannot'});
$can_daemon || &error($text{'start_ecannot'});

if ($config{'start_cmd'}) {
	$out = &backquote_logged("$config{'start_cmd'} 2>&1");
	}
else {
	$in{'interval'} =~ /^\d+$/ || &error($text{'start_einterval'});
	$mda = " -m '$config{'mda_command'}'" if ($config{'mda_command'});
	if ($< == 0) {
		if ($config{'daemon_user'} eq 'root') {
			$out = &backquote_logged("$config{'fetchmail_path'} -d $in{'interval'} -f $config{'config_file'} $mda 2>&1");
			}
		else {
			$out = &backquote_logged("su - '$config{'daemon_user'}' -c '$config{'fetchmail_path'} -d $in{'interval'} -f $config{'config_file'} $mda' 2>&1");
			}
		}
	else {
		$out = &backquote_logged("$config{'fetchmail_path'} -d $in{'interval'} $mda 2>&1");
		}
	}
if ($?) {
	&error("<tt>$out</tt>");
	}
&webmin_log("start", undef, undef, \%in);
&redirect("");

