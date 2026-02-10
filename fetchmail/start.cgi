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
	$mda = " -m ".quotemeta($config{'mda_command'}) if ($config{'mda_command'});
	my $qinterval = quotemeta($in{'interval'});
	my $qconfig_file = quotemeta($config{'config_file'});
	if ($< == 0) {
		if ($config{'daemon_user'} eq 'root') {
			$out = &backquote_logged("$config{'fetchmail_path'} -d $qinterval -f $qconfig_file $mda 2>&1");
			}
		else {
			my $qdaemon_user = quotemeta($config{'daemon_user'});
			my $daemon_cmd = "$config{'fetchmail_path'} -d $qinterval -f $qconfig_file $mda";
			$out = &backquote_logged("su - $qdaemon_user -c ".quotemeta($daemon_cmd)." 2>&1");
			}
		}
	else {
		$out = &backquote_logged("$config{'fetchmail_path'} -d $qinterval $mda 2>&1");
		}
	}
if ($?) {
	&error("<tt>$out</tt>");
	}
&webmin_log("start", undef, undef, \%in);
&redirect("");

